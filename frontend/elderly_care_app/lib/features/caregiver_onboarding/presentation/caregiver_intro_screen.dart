import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/care/care_buttons.dart';
import '../../../shared/widgets/care/care_feature_tile.dart';
import '../../../shared/widgets/care/care_hero_backdrop.dart';
import '../../../shared/widgets/care/care_responsive_page.dart';
import '../../../shared/widgets/care/care_reveal.dart';
import '../../../shared/widgets/care/onboarding_dots.dart';
import 'onboarding_steps.dart';
import 'welcome_hero.dart';

/// Onboarding page 2 of 2 (the last) — care introduction: what Sathi offers a caregiver.
///
/// Routes: Next and Skip → the existing `/login` (onboarding ends here).
///
/// Layout: hero (over its organic backdrop) → centred headline and subtitle → 2x2 benefit
/// tiles, then a fixed-height block with the pagination and Next pinned to the bottom on tall
/// screens. Short screens tighten spacing via [CareRhythm] and then scroll; nothing is clipped.
class CaregiverIntroScreen extends StatefulWidget {
  const CaregiverIntroScreen({super.key});

  @override
  State<CaregiverIntroScreen> createState() => _CaregiverIntroScreenState();
}

class _CaregiverIntroScreenState extends State<CaregiverIntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  bool _started = false;

  static const _benefits = [
    (icon: Icons.medical_services_outlined, label: 'Professional\nCaregivers', color: CareColors.primary, background: CareColors.primarySoft),
    (icon: Icons.verified_user_outlined, label: 'Verified\n& Safe', color: CareColors.accentWarm, background: CareColors.accentWarmSoft),
    (icon: Icons.home_outlined, label: 'In-Home\nCare', color: CareColors.accentBlue, background: CareColors.accentBlueSoft),
    (icon: Icons.groups_2_outlined, label: 'Personalized\nCare Plans', color: CareColors.accentViolet, background: CareColors.accentVioletSoft),
  ];

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

  // Page 2 is the last onboarding step: Next continues to the shared login. Pushed (like
  // page 1's Sign In) so Back returns here.
  void _next() => context.push('/login');

  // Same destination as page 1's Skip: the shared login, which routes each role home.
  void _skip() => context.go('/login');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CareColors.background,
      body: CareResponsivePage(builder: (context, viewport, insets) => _buildPage(viewport, insets)),
    );
  }

  Widget _buildPage(Size viewport, EdgeInsets insets) {
    final width = viewport.width;
    final height = viewport.height;
    final gap = CareRhythm(height).gap;

    const ctaGap = 20.0;
    final controlsHeight = 10 + ctaGap + CareSizes.ctaHeight + 14 + insets.bottom;
    final heroHeight = (height * 0.27).clamp(176.0, 310.0);
    final baseHeadline = CareText.headline(viewport);
    final headline = baseHeadline.copyWith(fontSize: baseHeadline.fontSize! * 0.92);

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [CareColors.backgroundTop, CareColors.background]),
          ),
          // In an unbounded scroll axis this Column sizes to max(viewport, content), and
          // spaceBetween pins the controls to the bottom on tall screens.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: insets.top + gap(4, 8)),
                  _buildHero(heroHeight),
                  SizedBox(height: gap(8, 14)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CareSpacing.screenH),
                    child: Column(
                      children: [
                        Reveal(
                          controller: _entrance,
                          begin: 0.2,
                          end: 0.6,
                          child: Semantics(
                            header: true,
                            label: 'Care Today for a Brighter Tomorrow',
                            excludeSemantics: true,
                            child: Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(text: 'Care Today\nfor a Brighter\n'),
                                  TextSpan(
                                    text: 'Tomorrow',
                                    style: TextStyle(color: CareColors.primary),
                                  ),
                                ],
                              ),
                              style: headline,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        SizedBox(height: gap(8, 12)),
                        Reveal(
                          controller: _entrance,
                          begin: 0.28,
                          end: 0.68,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: const Text('Trusted caregiving support\nfor your loved ones.', style: CareText.body, textAlign: TextAlign.center),
                          ),
                        ),
                        SizedBox(height: gap(14, 18)),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: width < 360 ? width : 420),
                          child: _buildBenefitGrid(),
                        ),
                        SizedBox(height: gap(10, 12)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: controlsHeight, child: _buildControls(insets.bottom, ctaGap)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(double heroHeight) {
    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Reveal(controller: _entrance, begin: 0.0, end: 0.5, offset: Offset.zero, scaleFrom: 0.92, child: const CareHeroBackdrop()),
          ),
          Positioned.fill(
            top: heroHeight * 0.1,
            child: Reveal(
              controller: _entrance,
              begin: 0.08,
              end: 0.6,
              offset: const Offset(0, 0.04),
              scaleFrom: 0.96,
              // Fade the photo's lower edge into the page, as in the reference.
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0.0, 0.84, 1.0],
                ).createShader(bounds),
                child: const CaregiverHero.intro(),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: CareSpacing.screenH,
            child: Reveal(
              controller: _entrance,
              begin: 0.0,
              end: 0.4,
              child: CareSoftPillButton(label: 'Skip', onPressed: _skip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitGrid() {
    Widget tile(int i) {
      final b = _benefits[i];
      return Reveal(
        controller: _entrance,
        begin: 0.36 + i * 0.07,
        end: 0.76 + i * 0.06,
        child: CareFeatureTile(icon: b.icon, label: b.label, iconColor: b.color, background: b.background),
      );
    }

    Widget row(int a, int b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tile(a)),
          const SizedBox(width: CareSpacing.md),
          Expanded(child: tile(b)),
        ],
      ),
    );

    return Column(
      children: [
        row(0, 1),
        const SizedBox(height: CareSpacing.md),
        row(2, 3),
      ],
    );
  }

  Widget _buildControls(double bottomInset, double ctaGap) {
    return Reveal(
      controller: _entrance,
      begin: 0.55,
      end: 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(CareSpacing.screenH, 0, CareSpacing.screenH, 14 + bottomInset),
        child: Column(
          children: [
            const SizedBox(height: 10, child: OnboardingDots.onLight(index: 1, count: caregiverOnboardingStepCount)),
            SizedBox(height: ctaGap),
            CarePrimaryCta.filled(label: 'Next', onPressed: _next),
          ],
        ),
      ),
    );
  }
}
