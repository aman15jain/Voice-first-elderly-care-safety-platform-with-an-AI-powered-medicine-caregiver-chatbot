import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/care/care_card.dart';
import '../../../shared/widgets/care/care_skeleton.dart';
import '../../dashboard/domain/elder_dashboard_row.dart';
import '../../dashboard/presentation/adherence_sparkline.dart';
import '../../medicines/domain/medicine_models.dart';
import '../../notifications/domain/app_notification.dart';
import '../application/caregiver_home_providers.dart';

// Every section here owns its own loading / empty / error state, so one failing request
// never blanks the whole dashboard. Error copy comes from AppFailure (friendly, no internals).

String _time(DateTime t) => DateFormat.jm().format(t);

const _danger = Color(0xFFC62828);
const _dangerSoft = Color(0xFFFDECEA);

/// Small inline "couldn't load — Retry" row used inside a section.
class SectionError extends StatelessWidget {
  const SectionError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: CareColors.textMuted),
        const SizedBox(width: CareSpacing.md),
        Expanded(child: Text(message, style: CareText.cardBody)),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: CareColors.primary,
            minimumSize: const Size(64, CareSizes.minTouch),
            visualDensity: VisualDensity.standard,
          ),
          child: const Text('Retry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Rounded pastel icon square — the visual unit shared by shortcuts, service tiles and
/// section icons (the reference's category-tile look).
class CareIconSquare extends StatelessWidget {
  const CareIconSquare({super.key, required this.icon, required this.color, required this.background, this.size = 64});

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * 0.32),
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: CareShadows.tile,
    ),
    child: Icon(icon, color: color, size: size * 0.46),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fg, required this.bg});
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(CareRadius.pill)),
    child: Text(
      text,
      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

class _ElderAvatar extends StatelessWidget {
  const _ElderAvatar({required this.name, this.radius = 28});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: radius * 2,
    height: radius * 2,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: CareColors.surface, shape: BoxShape.circle, boxShadow: CareShadows.tile),
    child: Text(
      name.characters.first.toUpperCase(),
      style: TextStyle(fontSize: radius * 0.85, fontWeight: FontWeight.w800, color: CareColors.primaryDark),
    ),
  );
}

// ---------------------------------------------------------------------------------------
// Safety: active emergency (only when one exists — never alarming otherwise).

class EmergencyBanner extends StatelessWidget {
  const EmergencyBanner({super.key, required this.elderName});
  final String elderName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _dangerSoft,
        borderRadius: BorderRadius.circular(CareRadius.card),
        border: Border.all(color: const Color(0xFFF5C2BF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CareSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: 'Emergency alert. Please check on $elderName.',
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: _danger, shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: CareSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Alert', style: CareText.cardTitle.copyWith(color: const Color(0xFFB71C1C))),
                        const SizedBox(height: 2),
                        Text('Please check on $elderName.', style: CareText.cardBody.copyWith(color: const Color(0xFF7F1D1D))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CareSpacing.md),
            // Navigation only — responding happens on the existing Alerts screen.
            FilledButton(
              onPressed: () => context.go('/caregiver/alerts'),
              style: FilledButton.styleFrom(
                backgroundColor: _danger,
                minimumSize: const Size.fromHeight(CareSizes.minTouch),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('View Alert'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// No loved one linked yet.

class NoElderCard extends StatelessWidget {
  const NoElderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CareCard(
      color: CareColors.primarySoft,
      padding: const EdgeInsets.all(CareSpacing.xl),
      child: Column(
        children: [
          const CareIconSquare(icon: Icons.diversity_3, color: CareColors.primary, background: CareColors.surface, size: 72),
          const SizedBox(height: CareSpacing.lg),
          const Text('No loved one connected yet.', style: CareText.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: CareSpacing.xs),
          const Text(
            'Connect with the person you care for to see their medicines, activity and alerts here.',
            style: CareText.cardBody,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CareSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.go('/caregiver/family'),
            style: FilledButton.styleFrom(
              backgroundColor: CareColors.primaryDark,
              minimumSize: const Size(200, 54),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Connect Someone'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Sathi AI assistant card — the entry into the existing caregiver-insight pipeline
// (Flutter → Node → agentic-ai). Opens [showInsightSheet].

class SathiAssistantCard extends StatefulWidget {
  const SathiAssistantCard({super.key, required this.row});

  /// The selected loved one, or null when none is linked yet.
  final ElderDashboardRow? row;

  @override
  State<SathiAssistantCard> createState() => _SathiAssistantCardState();
}

class _SathiAssistantCardState extends State<SathiAssistantCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _pulsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulsed) {
      // A few gentle pulses on arrival, then it rests — never perpetual motion.
      _pulsed = true;
      _pulse.repeat(reverse: true, count: 3);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final prompt = row == null ? 'Connect a loved one to get AI care insights' : 'Get a care summary for ${row.displayName}';
    final radius = BorderRadius.circular(28);

    return Semantics(
      container: true,
      button: true,
      label: 'Sathi AI. How can I help with care today? $prompt.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E8A66), CareColors.primaryDark, CareColors.primaryDeepest],
          ),
          boxShadow: CareShadows.buttonOnLight,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: row == null ? () => context.go('/caregiver/family') : () => showInsightSheet(context, row),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Positioned(right: -36, top: -44, child: _glow(150)),
                  Positioned(right: 70, bottom: -60, child: _glow(120)),
                  Padding(
                    padding: const EdgeInsets.all(CareSpacing.lg + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ScaleTransition(
                              scale: Tween<double>(begin: 1, end: 1.12).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                              ),
                            ),
                            const SizedBox(width: CareSpacing.sm + 2),
                            const Text(
                              'Sathi AI',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: CareSpacing.md + 2),
                        const Text(
                          'How can I help with care today?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3, color: Colors.white),
                        ),
                        const SizedBox(height: CareSpacing.lg),
                        // An assistant-style prompt surface. It is an action, not a text field:
                        // caregivers get the AI care insight — there is no free-form caregiver
                        // chat endpoint, so no input box or mic that couldn't work.
                        Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.only(left: CareSpacing.lg, right: 6, top: 6, bottom: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(CareRadius.pill)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prompt,
                                  style: const TextStyle(fontSize: 16, color: CareColors.textMuted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: CareSpacing.sm),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(color: CareColors.primaryDark, shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glow(double size) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
    ),
  );
}

/// Bottom sheet with the AI care insight for [row]. Records the request so the insight
/// card further down shows the same result — one LLM call serves both entry points.
Future<void> showInsightSheet(BuildContext context, ElderDashboardRow row) {
  ProviderScope.containerOf(context, listen: false).read(insightRequestsProvider.notifier).request(row.elderId);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CareColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => _InsightSheet(row: row),
  );
}

class _InsightSheet extends ConsumerWidget {
  const _InsightSheet({required this.row});
  final ElderDashboardRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(caregiverInsightProvider(row.elderId));
    final name = row.displayName;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(CareSpacing.xl, CareSpacing.md, CareSpacing.xl, CareSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: CareColors.primaryTint, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: CareSpacing.lg),
          Row(
            children: [
              const CareIconSquare(icon: Icons.auto_awesome, color: CareColors.primary, background: CareColors.primarySoft, size: 48),
              const SizedBox(width: CareSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sathi AI Insight', style: CareText.sectionTitle),
                    Text('For $name', style: CareText.cardBody),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CareSpacing.xl),
          insight.when(
            loading: () => Row(
              children: [
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: CareColors.primary)),
                const SizedBox(width: CareSpacing.md),
                Expanded(child: Text("Sathi AI is reviewing $name's care records…", style: CareText.body)),
              ],
            ),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sathi AI couldn't prepare an insight right now.", style: CareText.body),
                const SizedBox(height: CareSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(caregiverInsightProvider(row.elderId)),
                  style: OutlinedButton.styleFrom(foregroundColor: CareColors.primaryDark, minimumSize: const Size(0, 48), shape: const StadiumBorder()),
                  child: const Text('Try again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(CareSpacing.lg),
                  decoration: BoxDecoration(color: CareColors.primarySoft, borderRadius: BorderRadius.circular(CareRadius.tile)),
                  child: Text(value.response, style: CareText.body.copyWith(color: CareColors.textDark)),
                ),
                const SizedBox(height: CareSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: CareColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(child: Text("AI-generated from $name's care records.", style: CareText.cardBody.copyWith(fontSize: 14))),
                    TextButton(
                      onPressed: () => ref.invalidate(caregiverInsightProvider(row.elderId)),
                      style: TextButton.styleFrom(foregroundColor: CareColors.primary, minimumSize: const Size(48, 48), visualDensity: VisualDensity.standard),
                      child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Loved-one selector — a polished dropdown pill, only when several elders are linked.

class LovedOneSelector extends ConsumerWidget {
  const LovedOneSelector({super.key, required this.rows, required this.selected});

  final List<ElderDashboardRow> rows;
  final ElderDashboardRow selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      container: true,
      button: true,
      label: 'Viewing ${selected.displayName}. Change loved one.',
      excludeSemantics: true,
      child: Material(
        color: CareColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: CareColors.primaryTint)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _open(context, ref),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CareSizes.minTouch, maxWidth: 200),
            child: Padding(
              padding: const EdgeInsets.only(left: CareSpacing.md, right: CareSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      selected.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CareColors.primaryDark),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: CareColors.primaryDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: CareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(CareSpacing.lg, CareSpacing.lg, CareSpacing.lg, CareSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: CareSpacing.sm),
              child: Text('Your loved ones', style: CareText.sectionTitle),
            ),
            const SizedBox(height: CareSpacing.sm),
            for (final r in rows)
              ListTile(
                minTileHeight: 64,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CareRadius.tile)),
                selected: r.elderId == selected.elderId,
                selectedTileColor: CareColors.primarySoft,
                leading: _ElderAvatar(name: r.displayName, radius: 22),
                title: Text(
                  r.displayName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CareColors.textDark),
                ),
                subtitle: r.activeEmergency
                    ? const Text(
                        'Active emergency',
                        style: TextStyle(color: _danger, fontWeight: FontWeight.w600),
                      )
                    : null,
                trailing: r.elderId == selected.elderId ? const Icon(Icons.check_circle, color: CareColors.primary) : null,
                onTap: () {
                  ref.read(selectedElderIdProvider.notifier).select(r.elderId);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Today's care snapshot: the selected loved one at a glance, in readable rows.

class CareSnapshotCard extends ConsumerWidget {
  const CareSnapshotCard({super.key, required this.row, required this.unreadNotices});

  final ElderDashboardRow row;

  /// Real unread count from /api/notifications; null while loading or if it failed.
  final int? unreadNotices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(elderTodayCareProvider(row.elderId));
    final a = row.activity;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE6F3EC), Color(0xFFF7FBF8)]),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: CareShadows.tile,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CareSpacing.lg + 2, CareSpacing.lg + 2, CareSpacing.lg + 2, CareSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ElderAvatar(name: row.displayName),
                const SizedBox(width: CareSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.displayName, style: CareText.cardTitle.copyWith(fontSize: 20), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Text("Today's care", style: CareText.cardBody),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CareSpacing.md),
            today.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(bottom: CareSpacing.md),
                child: CareSkeleton(
                  child: Column(
                    children: [
                      CareSkeletonBlock(height: 54),
                      SizedBox(height: CareSpacing.sm),
                      CareSkeletonBlock(height: 54),
                    ],
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(bottom: CareSpacing.sm),
                child: SectionError(
                  message: "Today's medicines couldn't load. ${AppFailure.fromError(e).message}",
                  onRetry: () => ref.invalidate(elderTodayCareProvider(row.elderId)),
                ),
              ),
              data: (care) {
                final next = care.next;
                return Column(
                  children: [
                    _SnapshotRow(
                      icon: Icons.medication_outlined,
                      color: CareColors.primary,
                      label: 'Medicines',
                      value: care.total == 0 ? 'None scheduled today' : '${care.taken} of ${care.total} taken',
                      trailing: care.missed > 0 ? _Pill(text: '${care.missed} missed', fg: const Color(0xFFB4441C), bg: CareColors.accentWarmSoft) : null,
                    ),
                    _SnapshotRow(
                      icon: Icons.schedule,
                      color: CareColors.accentBlue,
                      label: 'Next dose',
                      value: next == null ? (care.total == 0 ? '—' : 'All done for today') : '${_time(next.dose.scheduledFor)} · ${next.medicineName}',
                    ),
                  ],
                );
              },
            ),
            _SnapshotRow(
              icon: Icons.directions_walk,
              color: CareColors.accentViolet,
              label: 'Activity',
              value: 'Active ${a.activeDays} of last ${a.daysInRange} days',
            ),
            _SnapshotRow(
              icon: Icons.notifications_none,
              color: CareColors.accentWarm,
              label: 'Notices',
              value: switch (unreadNotices) {
                null => '—',
                0 => 'No unread notices',
                1 => '1 unread notice',
                final n => '$n unread notices',
              },
              onTap: () => context.go('/caregiver/notifications'),
            ),
            _SnapshotRow(
              icon: row.activeEmergency ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
              color: row.activeEmergency ? _danger : CareColors.primary,
              label: 'Safety',
              value: row.activeEmergency ? 'Active emergency' : 'No active alerts',
              onTap: () => context.go('/caregiver/alerts'),
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.icon, required this.color, required this.label, required this.value, this.trailing, this.onTap, this.last = false});

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: CareSpacing.sm + 2),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: CareColors.surface, shape: BoxShape.circle, boxShadow: CareShadows.tile),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: CareSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CareColors.textMuted),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CareColors.textDark, height: 1.25),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: CareSpacing.sm), trailing!],
          if (onTap != null) const Icon(Icons.chevron_right, color: CareColors.textMuted),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          if (onTap == null) content else InkWell(borderRadius: BorderRadius.circular(CareRadius.tile), onTap: onTap, child: content),
          if (!last) Divider(height: 1, color: CareColors.primaryTint.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Quick actions — a horizontally scrolling row of premium icon tiles. Only real
// destinations: caregiver tabs, Settings, Sathi AI, or jumps to sections of this page.

class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.color, required this.background, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final int? badge;
}

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key, required this.actions, required this.sidePadding});

  final List<QuickAction> actions;

  /// Lets the row scroll edge to edge while its first tile lines up with the page content.
  final double sidePadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: CareSpacing.sm),
        itemBuilder: (context, i) {
          final a = actions[i];
          final badge = a.badge ?? 0;
          return Semantics(
            container: true,
            button: true,
            label: badge > 0 ? '${a.label}, $badge unread' : a.label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(CareRadius.tile),
              onTap: a.onTap,
              // 76 wide + 8 gap: on a 390 phone the fifth tile peeks in, hinting the row scrolls.
              child: SizedBox(
                width: 76,
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CareIconSquare(icon: a.icon, color: a.color, background: a.background, size: 62),
                        if (badge > 0)
                          Positioned(
                            top: -5,
                            right: -5,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                '$badge',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: CareSpacing.sm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        a.label,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: CareColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Today's care plan: a timeline of today's scheduled doses.

class CarePlanTimeline extends ConsumerWidget {
  const CarePlanTimeline({super.key, required this.row});
  final ElderDashboardRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(elderTodayCareProvider(row.elderId));
    return CareCard(
      padding: const EdgeInsets.fromLTRB(CareSpacing.lg, CareSpacing.md, CareSpacing.lg, CareSpacing.md),
      child: today.when(
        loading: () => const CareSkeleton(
          child: Column(
            children: [
              CareSkeletonBlock(height: 56),
              SizedBox(height: CareSpacing.sm),
              CareSkeletonBlock(height: 56),
            ],
          ),
        ),
        error: (e, _) => SectionError(message: "Today's plan couldn't load.", onRetry: () => ref.invalidate(elderTodayCareProvider(row.elderId))),
        data: (care) => care.doses.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: CareSpacing.sm),
                child: Row(
                  children: [
                    const CareIconSquare(icon: Icons.event_available, color: CareColors.primary, background: CareColors.primarySoft, size: 52),
                    const SizedBox(width: CareSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('No medicines scheduled for today.', style: CareText.cardTitle),
                          const SizedBox(height: 4),
                          Text("Medicines and their times are set up in ${row.displayName}'s Sathi app.", style: CareText.cardBody),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < care.doses.length; i++) _TimelineEntry(dose: care.doses[i], isFirst: i == 0, isLast: i == care.doses.length - 1),
                ],
              ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.dose, required this.isFirst, required this.isLast});

  final DoseView dose;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, icon, filled) = switch (dose.dose.status) {
      DoseStatus.taken => ('Taken', CareColors.primary, CareColors.primarySoft, Icons.check, true),
      DoseStatus.missed => ('Missed', const Color(0xFFB4441C), CareColors.accentWarmSoft, Icons.close, true),
      DoseStatus.skipped => ('Skipped', CareColors.textMuted, const Color(0xFFEDEFF1), Icons.remove, true),
      DoseStatus.reminded => ('Reminded', CareColors.accentBlue, CareColors.accentBlueSoft, Icons.notifications_active_outlined, false),
      DoseStatus.scheduled => ('Upcoming', CareColors.accentBlue, CareColors.accentBlueSoft, Icons.schedule, false),
    };
    final time = _time(dose.dose.scheduledFor);
    const rail = CareColors.primaryTint;

    return Semantics(
      container: true,
      label: '$time, ${dose.medicineName}${dose.dosage.isEmpty ? '' : ' ${dose.dosage}'}, $label',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 74,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Text(
                    time,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: CareColors.textDark),
                  ),
                ),
              ),
            ),
            // Rail + status node.
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  Container(width: 2, height: 12, color: isFirst ? Colors.transparent : rail),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? fg : CareColors.surface,
                      border: Border.all(color: fg, width: 2),
                    ),
                    child: Icon(icon, size: 16, color: filled ? Colors.white : fg),
                  ),
                  Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : rail)),
                ],
              ),
            ),
            const SizedBox(width: CareSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CareSpacing.sm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dose.medicineName,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: CareColors.textDark),
                    ),
                    if (dose.dosage.isNotEmpty) Text(dose.dosage, style: CareText.cardBody.copyWith(fontSize: 14.5)),
                    const SizedBox(height: 6),
                    _Pill(text: label, fg: fg, bg: bg),
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

// ---------------------------------------------------------------------------------------
// Health & activity — straight from the dashboard row (no extra request) plus the existing
// per-elder adherence trend sparkline. The ring only visualises the backend's own rate.

class HealthActivityCard extends StatelessWidget {
  const HealthActivityCard({super.key, required this.row});
  final ElderDashboardRow row;

  @override
  Widget build(BuildContext context) {
    final rate = row.adherence.takenRate;
    final a = row.activity;

    return CareCard(
      padding: const EdgeInsets.all(CareSpacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: rate == null ? 'Medicine adherence: no doses due yet' : 'Medicine adherence, last 30 days: $rate percent',
            excludeSemantics: true,
            child: Row(
              children: [
                _AdherenceRing(rate: rate),
                const SizedBox(width: CareSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Medicine adherence', style: CareText.cardTitle),
                      const SizedBox(height: 2),
                      Text(rate == null ? 'No doses due yet' : 'Doses taken · last 30 days', style: CareText.cardBody),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CareSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(CareSpacing.md, CareSpacing.md, CareSpacing.md, CareSpacing.sm),
            decoration: BoxDecoration(color: CareColors.background, borderRadius: BorderRadius.circular(CareRadius.tile)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily trend',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CareColors.textMuted),
                ),
                const SizedBox(height: CareSpacing.sm),
                AdherenceSparkline(elderId: row.elderId),
              ],
            ),
          ),
          const SizedBox(height: CareSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.directions_walk,
                  label: 'Active',
                  value: a.activeDays,
                  of: a.daysInRange,
                  color: CareColors.primary,
                  background: CareColors.primarySoft,
                ),
              ),
              const SizedBox(width: CareSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.medication_outlined,
                  label: 'Check-ins',
                  value: a.medicineInteractionDays,
                  of: a.daysInRange,
                  color: CareColors.accentBlue,
                  background: CareColors.accentBlueSoft,
                ),
              ),
              const SizedBox(width: CareSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.extension_outlined,
                  label: 'Brain games',
                  value: a.gameSessionDays,
                  of: a.daysInRange,
                  color: CareColors.accentViolet,
                  background: CareColors.accentVioletSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdherenceRing extends StatelessWidget {
  const _AdherenceRing({required this.rate});
  final int? rate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: rate == null ? 0 : rate! / 100,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              color: CareColors.primary,
              backgroundColor: CareColors.primarySoft,
            ),
          ),
          Text(
            rate == null ? '—' : '$rate%',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CareColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.of, required this.color, required this.background});

  final IconData icon;
  final String label;
  final int value;
  final int of;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final fraction = of == 0 ? 0.0 : (value / of).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: '$label on $value of the last $of days',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(CareSpacing.sm + 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(CareRadius.tile)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$value/$of days',
                maxLines: 1,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CareColors.textDark),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CareColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(CareRadius.pill),
              child: LinearProgressIndicator(value: fraction, minHeight: 6, color: color, backgroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Notices — the caregiver's unread notifications (missed doses, SOS); same name as the tab.

class NoticesCard extends StatelessWidget {
  const NoticesCard({super.key, required this.notifications, required this.onRetry});

  final AsyncValue<List<AppNotification>> notifications;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CareCard(
      padding: const EdgeInsets.symmetric(horizontal: CareSpacing.lg, vertical: CareSpacing.sm),
      child: notifications.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: CareSpacing.sm),
          child: CareSkeleton(
            child: Column(
              children: [
                CareSkeletonBlock(height: 48),
                SizedBox(height: CareSpacing.sm),
                CareSkeletonBlock(height: 48),
              ],
            ),
          ),
        ),
        error: (e, _) => SectionError(message: "Notices couldn't load.", onRetry: onRetry),
        data: (all) {
          final unread = all.where((n) => n.isUnread).toList();
          if (unread.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: CareSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: CareColors.primary, size: 26),
                  SizedBox(width: CareSpacing.md),
                  Expanded(child: Text("You're all caught up.", style: CareText.cardTitle)),
                ],
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < unread.length && i < 3; i++) ...[
                if (i > 0) Divider(height: 1, color: CareColors.primaryTint.withValues(alpha: 0.6)),
                _NoticeRow(notification: unread[i]),
              ],
              if (unread.length > 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: CareSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('+${unread.length - 3} more unread', style: CareText.cardBody),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final sos = notification.type == AppNotificationType.emergencySos;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CareSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CareIconSquare(
                icon: sos ? Icons.sos : Icons.medication_outlined,
                color: sos ? _danger : CareColors.accentWarm,
                background: sos ? _dangerSoft : CareColors.accentWarmSoft,
                size: 44,
              ),
              // Unread marker.
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: CareSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CareColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(notification.body, style: CareText.cardBody.copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Find Care — caregiver discovery/booking is not part of Sathi yet. A secondary, honest
// "coming soon" section: no fake caregivers, prices, ratings or booking.

class FindCareSection extends StatelessWidget {
  const FindCareSection({super.key});

  static const _services = [
    (icon: Icons.medical_services_outlined, label: 'Nursing\nCare', color: CareColors.primary, bg: CareColors.primarySoft),
    (icon: Icons.elderly, label: 'Elder\nCare', color: CareColors.accentWarm, bg: CareColors.accentWarmSoft),
    (icon: Icons.accessibility_new, label: 'Physio-\ntherapy', color: CareColors.accentBlue, bg: CareColors.accentBlueSoft),
    (icon: Icons.volunteer_activism_outlined, label: 'Companion\nCare', color: CareColors.accentViolet, bg: CareColors.accentVioletSoft),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Find Care, coming soon. Need additional professional support? Nursing care, elder care, physiotherapy and companion care.',
      excludeSemantics: true,
      child: CareCard(
        padding: const EdgeInsets.all(CareSpacing.lg + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(child: Text('Find Care', style: CareText.sectionTitle)),
                _Pill(text: 'Coming soon', fg: CareColors.primaryDark, bg: CareColors.primarySoft),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Need additional professional support?', style: CareText.cardBody),
            const SizedBox(height: CareSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = CareSpacing.sm;
                final tile = (constraints.maxWidth - gap * 3) / 4;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _services.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: tile,
                        child: Column(
                          children: [
                            CareIconSquare(icon: _services[i].icon, color: _services[i].color, background: _services[i].bg, size: math.min(60, tile)),
                            const SizedBox(height: CareSpacing.sm),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _services[i].label,
                                textAlign: TextAlign.center,
                                softWrap: false,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.2, color: CareColors.textDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Sathi AI insight card — shows the insight once requested (same provider as the sheet).

class InsightCard extends ConsumerWidget {
  const InsightCard({super.key, required this.row});
  final ElderDashboardRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requested = ref.watch(insightRequestsProvider).contains(row.elderId);
    final name = row.displayName;

    final Widget body;
    if (!requested) {
      body = Text("A short AI summary of $name's recent medicines and activity, from their care records.", style: CareText.cardBody);
    } else {
      body = ref
          .watch(caregiverInsightProvider(row.elderId))
          .when(
            loading: () => Text("Sathi AI is reviewing $name's care records…", style: CareText.cardBody),
            error: (e, _) => const Text("Sathi AI couldn't prepare an insight right now.", style: CareText.cardBody),
            data: (v) => Text(
              '“${v.response}”',
              style: CareText.body.copyWith(color: CareColors.textDark, fontStyle: FontStyle.italic),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          );
    }

    return CareCard(
      color: const Color(0xFFF1F8F4),
      padding: const EdgeInsets.all(CareSpacing.lg + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CareIconSquare(icon: Icons.auto_awesome, color: CareColors.primary, background: CareColors.surface, size: 44),
              SizedBox(width: CareSpacing.md),
              Expanded(child: Text('Sathi AI Insight', style: CareText.cardTitle)),
            ],
          ),
          const SizedBox(height: CareSpacing.md),
          body,
          const SizedBox(height: CareSpacing.lg),
          FilledButton.icon(
            onPressed: () => showInsightSheet(context, row),
            style: FilledButton.styleFrom(
              backgroundColor: CareColors.primaryDark,
              minimumSize: const Size(0, 52),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: Text(requested ? 'View Insight' : 'Get Care Insight'),
          ),
        ],
      ),
    );
  }
}
