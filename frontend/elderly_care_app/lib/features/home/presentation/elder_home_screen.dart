import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/sync_queue_service.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/care/care_connect_logo.dart';
import '../../../shared/widgets/care/care_pill.dart';
import '../../../shared/widgets/care/care_states.dart';
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
        title: const CareConnectLogo(markSize: 40, wordmarkSize: 26, showTagline: false),
        actions: [IconButton(icon: const Icon(Icons.person), tooltip: 'Profile', onPressed: () => context.push('/profile'))],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nextDoseProvider);
            ref.invalidate(todayScheduleProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.xs, CareSpacing.screenH - 4, CareSpacing.xl),
            children: [
              Text('Good day, $name', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(DateFormat.MMMMEEEEd().format(DateTime.now()), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: CareSpacing.lg),
              _TalkCard(onTap: () => context.push('/voice')),
              const SizedBox(height: CareSpacing.lg),
              nextDose.when(
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => CareInlineError(message: AppFailure.fromError(e).message),
                data: (view) => view == null ? const _AllCaughtUpCard() : _NextMedicineCard(view: view),
              ),
              schedule.maybeWhen(
                data: (views) {
                  if (views.isEmpty) return const SizedBox.shrink();
                  final taken = views.where((v) => v.dose.status == DoseStatus.taken).length;
                  return Padding(
                    padding: const EdgeInsets.only(top: CareSpacing.xs),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => context.push('/medicines/today'),
                        icon: const Icon(Icons.event_note),
                        label: Text("See today's full schedule ($taken/${views.length} taken)"),
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              // Emergency sits right after the medicine section so it is visible without scrolling.
              const SizedBox(height: CareSpacing.sm),
              BigButton(label: 'Emergency', icon: Icons.warning_amber, color: CareColors.danger, onPressed: () => context.push('/emergency')),
              const SizedBox(height: CareSpacing.lg),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _HomeTile(
                        icon: Icons.extension,
                        color: CareColors.accentViolet,
                        background: CareColors.accentVioletSoft,
                        label: 'Play Game',
                        onTap: () => context.push('/games'),
                      ),
                    ),
                    const SizedBox(width: CareSpacing.md),
                    Expanded(
                      child: _HomeTile(
                        icon: Icons.insights,
                        color: CareColors.accentBlue,
                        background: CareColors.accentBlueSoft,
                        label: 'See this week’s activity',
                        onTap: () => context.push('/activity'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The voice assistant entry — the elder's primary action, so it is the hero of the page.
class _TalkCard extends StatelessWidget {
  const _TalkCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Talk. Ask about your medicines or call your family.',
      excludeSemantics: true,
      child: Material(
        borderRadius: BorderRadius.circular(CareRadius.card),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [CareColors.primary, CareColors.primaryDark]),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(CareSpacing.lg + 4),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.mic, size: 36, color: CareColors.primaryDark),
                  ),
                  const SizedBox(width: CareSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Talk', style: text.headlineSmall?.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Ask about medicines or call family', style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.icon, required this.color, required this.background, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CareSpacing.md),
          child: Row(
            children: [
              CareIconTile(icon: icon, color: color, background: background, size: 44),
              const SizedBox(width: CareSpacing.md),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
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
    return Container(
      padding: const EdgeInsets.all(CareSpacing.lg + 4),
      decoration: BoxDecoration(color: CareColors.successSoft, borderRadius: BorderRadius.circular(CareRadius.card)),
      child: Row(
        children: [
          const CareIconTile(icon: Icons.check_circle, color: CareColors.success, background: Colors.white, circle: true),
          const SizedBox(width: CareSpacing.lg),
          Expanded(child: Text('All caught up! No medicines due right now.', style: Theme.of(context).textTheme.titleMedium)),
        ],
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
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(CareSpacing.lg + 4),
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
                      Text('Next Medicine', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(widget.view.medicineName, style: text.headlineSmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CareSpacing.md),
            CareStatusPill(label: '${widget.view.dosage} • $time', icon: Icons.schedule),
            const SizedBox(height: CareSpacing.lg),
            BigButton(label: 'Take Medicine', icon: Icons.check, isLoading: _isSubmitting, onPressed: _markTaken),
          ],
        ),
      ),
    );
  }
}
