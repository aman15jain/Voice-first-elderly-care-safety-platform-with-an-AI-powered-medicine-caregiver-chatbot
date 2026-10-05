import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/care/care_card.dart';
import '../../../shared/widgets/care/care_connect_logo.dart';
import '../../../shared/widgets/care/care_hero_backdrop.dart';
import '../../../shared/widgets/care/care_reveal.dart';
import '../../../shared/widgets/care/care_skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../caregiver_onboarding/presentation/welcome_hero.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/domain/elder_dashboard_row.dart';
import '../../notifications/application/notifications_providers.dart';
import '../application/caregiver_home_providers.dart';
import 'caregiver_home_sections.dart';

/// The caregiver's home: one calm overview of everything about the people they care for.
///
/// Data (all existing endpoints, nothing computed beyond simple tallies):
/// * GET /api/family/dashboard — every linked elder's 30-day adherence, 7-day activity and
///   active-emergency flag in ONE call (also feeds Health & Activity, no extra request).
/// * GET /api/doses + /api/medicines ?elderId — today's plan for the selected elder.
/// * GET /api/notifications — unread notices (missed doses, SOS).
/// * GET /api/adherence/trend ?elderId — the existing sparkline.
/// * GET /api/ai/caregiver-insight ?elderId — only when the caregiver asks Sathi AI.
///
/// Order puts care first: safety → greeting → Sathi AI → today's care → shortcuts → plan →
/// health → notices → find care (secondary) → AI insight.
class CaregiverHomeScreen extends ConsumerStatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  ConsumerState<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends ConsumerState<CaregiverHomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  // Anchors so shortcuts can jump to sections on this page.
  final _planKey = GlobalKey();
  final _healthKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    startCareEntrance(context, _entrance);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Pull-to-refresh: reload every section (families invalidate for all elders). Picks up
  /// anything changed elsewhere — e.g. a dose the elder just confirmed.
  Future<void> _refresh() async {
    ref.invalidate(caregiverDashboardProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(elderTodayCareProvider);
    ref.invalidate(adherenceTrendProvider);
    // Errors are shown by the sections themselves; the spinner just needs to stop.
    await ref.read(caregiverDashboardProvider.future).then((_) {}, onError: (_) {});
  }

  void _jumpTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  ElderDashboardRow? _selected(List<ElderDashboardRow>? rows) {
    if (rows == null || rows.isEmpty) return null;
    final id = ref.watch(selectedElderIdProvider);
    return rows.firstWhere((r) => r.elderId == id, orElse: () => rows.first);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = auth is AuthAuthenticated ? auth.user.displayName : '';
    final dashboard = ref.watch(caregiverDashboardProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.value?.where((n) => n.isUnread).length;
    final rows = dashboard.value;
    final selected = _selected(rows);

    var section = 0;
    Widget reveal(Widget child) {
      final i = section++;
      final begin = math.min(i * 0.06, 0.5);
      return Reveal(controller: _entrance, begin: begin, end: math.min(begin + 0.5, 1.0), child: child);
    }

    return Scaffold(
      backgroundColor: CareColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Phone-width column on wide windows; never stretched edge to edge.
            final hPad = math.max(20.0, (width - 600) / 2);
            Widget pad(Widget child) => Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: child,
            );
            const gapL = SizedBox(height: CareSpacing.xxl);

            return RefreshIndicator(
              color: CareColors.primary,
              onRefresh: _refresh,
              // A single built column (not a lazy list) so shortcuts can jump to any section.
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: CareSpacing.sm, bottom: CareSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    pad(reveal(_Header(unreadCount: unreadCount ?? 0, caregiverName: name))),
                    if (rows != null)
                      for (final r in rows.where((r) => r.activeEmergency)) ...[
                        const SizedBox(height: CareSpacing.md),
                        pad(reveal(EmergencyBanner(elderName: r.displayName))),
                      ],
                    const SizedBox(height: CareSpacing.md),
                    pad(reveal(_Greeting(name: name, width: width - hPad * 2))),
                    const SizedBox(height: CareSpacing.xl),
                    pad(reveal(SathiAssistantCard(row: selected))),
                    gapL,
                    ..._todaysCare(dashboard, selected, unreadCount, pad, reveal),
                    gapL,
                    pad(reveal(const CareSectionHeader(title: 'Quick Actions'))),
                    const SizedBox(height: CareSpacing.xs),
                    reveal(QuickActionsRow(actions: _actions(selected, unreadCount ?? 0), sidePadding: hPad)),
                    if (selected != null) ...[
                      gapL,
                      pad(
                        KeyedSubtree(
                          key: _planKey,
                          child: reveal(const CareSectionHeader(title: "Today's Care Plan")),
                        ),
                      ),
                      const SizedBox(height: CareSpacing.xs),
                      pad(reveal(CarePlanTimeline(row: selected))),
                      gapL,
                      pad(
                        KeyedSubtree(
                          key: _healthKey,
                          child: reveal(const CareSectionHeader(title: 'Health & Activity')),
                        ),
                      ),
                      const SizedBox(height: CareSpacing.xs),
                      pad(reveal(HealthActivityCard(row: selected))),
                    ],
                    gapL,
                    pad(reveal(CareSectionHeader(title: 'Notices', actionLabel: 'See all', onAction: () => context.go('/caregiver/notifications')))),
                    const SizedBox(height: CareSpacing.xs),
                    pad(reveal(NoticesCard(notifications: notifications, onRetry: () => ref.invalidate(notificationsProvider)))),
                    gapL,
                    pad(reveal(const FindCareSection())),
                    if (selected != null) ...[const SizedBox(height: CareSpacing.lg), pad(reveal(InsightCard(row: selected)))],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The loved-one block: snapshot when linked, connect prompt when not, plus loading/error.
  List<Widget> _todaysCare(
    AsyncValue<List<ElderDashboardRow>> dashboard,
    ElderDashboardRow? selected,
    int? unreadCount,
    Widget Function(Widget) pad,
    Widget Function(Widget) reveal,
  ) {
    return dashboard.when(
      skipLoadingOnRefresh: true,
      loading: () => [pad(reveal(const CareSectionHeader(title: "Today's Care"))), pad(const CareSkeleton(child: CareSkeletonBlock(height: 300, radius: 28)))],
      error: (e, _) => [
        pad(reveal(const CareSectionHeader(title: "Today's Care"))),
        pad(
          reveal(
            CareCard(
              child: SectionError(
                message: "Your loved ones' overview couldn't load. ${AppFailure.fromError(e).message}",
                onRetry: () => ref.invalidate(caregiverDashboardProvider),
              ),
            ),
          ),
        ),
      ],
      data: (rows) {
        if (rows.isEmpty || selected == null) return [pad(reveal(const NoElderCard()))];
        return [
          pad(
            reveal(
              Row(
                children: [
                  const Expanded(child: CareSectionHeader(title: "Today's Care")),
                  if (rows.length > 1) LovedOneSelector(rows: rows, selected: selected),
                ],
              ),
            ),
          ),
          const SizedBox(height: CareSpacing.xs),
          pad(reveal(CareSnapshotCard(row: selected, unreadNotices: unreadCount))),
        ];
      },
    );
  }

  List<QuickAction> _actions(ElderDashboardRow? selected, int unread) {
    final hasElder = selected != null;
    void toFamily() => context.go('/caregiver/family');
    return [
      QuickAction(
        icon: Icons.auto_awesome,
        label: 'Sathi AI',
        color: CareColors.primary,
        background: CareColors.primarySoft,
        onTap: hasElder ? () => showInsightSheet(context, selected) : toFamily,
      ),
      QuickAction(
        icon: Icons.medication_outlined,
        label: 'Medicines',
        color: CareColors.accentBlue,
        background: CareColors.accentBlueSoft,
        onTap: hasElder ? () => _jumpTo(_planKey) : toFamily,
      ),
      QuickAction(
        icon: Icons.favorite_border,
        label: 'Health',
        color: CareColors.accentWarm,
        background: CareColors.accentWarmSoft,
        onTap: hasElder ? () => _jumpTo(_healthKey) : toFamily,
      ),
      QuickAction(icon: Icons.diversity_3, label: 'Loved Ones', color: CareColors.accentViolet, background: CareColors.accentVioletSoft, onTap: toFamily),
      QuickAction(
        icon: Icons.health_and_safety_outlined,
        label: 'Safety',
        color: const Color(0xFFC62828),
        background: const Color(0xFFFDECEA),
        onTap: () => context.go('/caregiver/alerts'),
      ),
      QuickAction(
        icon: Icons.notifications_none,
        label: 'Notices',
        color: CareColors.accentWarm,
        background: CareColors.accentPeachSoft,
        badge: unread,
        onTap: () => context.go('/caregiver/notifications'),
      ),
      QuickAction(
        icon: Icons.tune,
        label: 'Settings',
        color: CareColors.textMuted,
        background: const Color(0xFFEFF1F3),
        onTap: () => context.push('/settings'),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unreadCount, required this.caregiverName});

  final int unreadCount;
  final String caregiverName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The logo yields first on narrow screens / large text, so the buttons never overflow.
        Expanded(
          child: Semantics(
            container: true,
            label: CareConnectLogo.brandName,
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const CareConnectMark(size: 46),
                  const SizedBox(width: CareSpacing.sm),
                  Text(CareConnectLogo.brandName, style: CareText.brandName.copyWith(fontSize: 30, color: CareColors.primary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: CareSpacing.sm),
        _RoundButton(
          semanticLabel: unreadCount == 0 ? 'Notifications' : 'Notifications, $unreadCount unread',
          onTap: () => context.go('/caregiver/notifications'),
          // Fill the whole button so the badge can sit on its rim.
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none, size: 28, color: CareColors.textDark),
              if (unreadCount > 0)
                // Badge on the button's rim, clear of the bell glyph.
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: CareSpacing.sm),
        _RoundButton(
          semanticLabel: 'Your profile',
          onTap: () => context.go('/caregiver/profile'),
          color: CareColors.primaryDark,
          child: Center(
            child: Text(
              caregiverName.isEmpty ? '?' : caregiverName.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.semanticLabel, required this.onTap, required this.child, this.color = CareColors.surface});

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: CareShadows.tile),
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 52, height: 52, child: child),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.width});

  final String name;
  final double width;

  static String _partOfDay(DateTime now) {
    if (now.hour < 12) return 'Good Morning,';
    if (now.hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    // A generous hero beside the greeting (like the reference), scaled to the column.
    final heroWidth = (width * 0.44).clamp(118.0, 230.0);
    final heroHeight = heroWidth * 1.08;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _partOfDay(DateTime.now()),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: CareColors.textMuted),
              ),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(
                  name.isEmpty ? 'Welcome 👋' : '$name 👋',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -0.8, color: CareColors.textDark),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: CareSpacing.md),
              const Text('Everything your loved one needs, all in one place.', style: CareText.body),
            ],
          ),
        ),
        const SizedBox(width: CareSpacing.sm),
        SizedBox(
          width: heroWidth,
          height: heroHeight,
          child: const Stack(
            children: [
              Positioned.fill(child: CareHeroBackdrop()),
              Positioned.fill(top: 18, child: CaregiverHero.home()),
            ],
          ),
        ),
      ],
    );
  }
}
