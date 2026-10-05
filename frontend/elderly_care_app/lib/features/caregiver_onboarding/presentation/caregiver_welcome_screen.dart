import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/care/care_buttons.dart';
import '../../../shared/widgets/care/care_connect_logo.dart';
import '../../../shared/widgets/care/care_responsive_page.dart';
import '../../../shared/widgets/care/care_reveal.dart';
import '../../../shared/widgets/care/care_wave.dart';
import '../../../shared/widgets/care/onboarding_dots.dart';
import 'onboarding_steps.dart';
import 'welcome_hero.dart';
import 'welcome_widgets.dart';

/// Copy that is likely to change (or be sourced from the backend later) without a layout change.
///
/// The statistic below is demo content carried over from the supplied design. It is a
/// placeholder, not a verified figure — replace it before any production release.
class CaregiverWelcomeContent {
  const CaregiverWelcomeContent({this.statValue = '10,000+', this.statLabel = 'Families Trust Us'});

  final String statValue;
  final String statLabel;
}

/// Onboarding page 1 of 2 — the first caregiver-facing screen.
///
/// Routes: Get Started → `/welcome/intro` (page 2), Skip / Sign In → the existing `/login`.
///
/// Layout: one stack per page — back wave, hero, front wave, then the content column on top —
/// so text and the stat card always stay readable over the hero, and the hero sinks behind the
/// dark wave. The block on the wave (dots, CTA, Sign In) has a fixed height, which lets the
/// wave and hero be anchored to it precisely. Short screens scroll; nothing is clipped.
class CaregiverWelcomeScreen extends StatefulWidget {
  const CaregiverWelcomeScreen({super.key, this.content = const CaregiverWelcomeContent()});

  final CaregiverWelcomeContent content;

  @override
  State<CaregiverWelcomeScreen> createState() => _CaregiverWelcomeScreenState();
}

class _CaregiverWelcomeScreenState extends State<CaregiverWelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

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

  void _getStarted() => context.push('/welcome/intro');

  // Onboarding is skipped straight to the existing entry screen. There is no separate caregiver
  // login: /login serves every role and routes to the right home after authentication.
  void _skip() => context.go('/login');

  void _signIn() => context.push('/login');

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

    final controlsHeight = 10 + 20 + CareSizes.ctaHeight + 6 + CareSizes.minTouch + 10 + insets.bottom;
    final waveZone = gap(56, 80);
    final waveBaseline = waveZone + 8;

    var heroHeight = (height * 0.44).clamp(250.0, 420.0);
    var heroWidth = heroHeight * CaregiverHero.welcomeAspectRatio;
    if (heroWidth > width * 0.8) {
      heroWidth = width * 0.8;
      heroHeight = heroWidth / CaregiverHero.welcomeAspectRatio;
    }

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [CareColors.backgroundTop, CareColors.background]),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: waveBaseline + controlsHeight,
              child: CareWaveLayer.back(baseline: waveBaseline),
            ),
            Positioned(
              right: -width * 0.06,
              // Sinks just below the top of the wave content, behind the dark wave.
              bottom: controlsHeight - 10,
              width: heroWidth,
              height: heroHeight,
              child: Reveal(controller: _entrance, begin: 0.3, end: 0.85, offset: const Offset(0.04, 0.03), child: const CaregiverHero.welcome()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: waveBaseline + controlsHeight,
              child: CareWaveLayer.front(baseline: waveBaseline),
            ),
            // In an unbounded scroll axis this Column sizes to max(viewport, content), and
            // spaceBetween pins the controls to the bottom on tall screens.
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(CareSpacing.screenH, insets.top + gap(4, 8), CareSpacing.screenH, 0),
                  child: _buildContent(viewport, gap, waveZone),
                ),
                SizedBox(height: controlsHeight, child: _buildControls(insets.bottom)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Size viewport, double Function(double, double) gap, double waveZone) {
    final width = viewport.width;
    final headline = CareText.headline(viewport);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Skip shares the wordmark line so the tagline runs full width beneath.
        Reveal(
          controller: _entrance,
          begin: 0.0,
          end: 0.45,
          offset: const Offset(-0.03, 0),
          child: CareConnectLogo(
            markSize: (width * 0.155).clamp(50.0, 66.0),
            wordmarkSize: (width * 0.08).clamp(26.0, 34.0),
            trailing: CareSoftPillButton(label: 'Skip', onPressed: _skip),
          ),
        ),
        SizedBox(height: gap(14, 24)),

        // Headline + floating stat card beside the short last line, where it can never collide
        // with the headline however the width changes.
        Reveal(
          controller: _entrance,
          begin: 0.12,
          end: 0.58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                label: 'Compassionate Care You Can Trust',
                excludeSemantics: true,
                child: Text('Compassionate\nCare You Can', style: headline),
              ),
              Row(
                children: [
                  ExcludeSemantics(
                    child: Text('Trust', style: headline.copyWith(color: CareColors.primary)),
                  ),
                  const SizedBox(width: CareSpacing.lg),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      // Nudged toward the screen edge and down, floating over the hero area.
                      child: Transform.translate(
                        offset: const Offset(14, 6),
                        child: TrustStatCard(value: widget.content.statValue, label: widget.content.statLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: gap(10, 14)),

        Reveal(
          controller: _entrance,
          begin: 0.2,
          end: 0.65,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.min(width * 0.66, 320)),
            child: const Text('Find verified caregivers, nurses and companions for your loved ones.', style: CareText.body),
          ),
        ),
        SizedBox(height: gap(14, 22)),

        // Staggered benefits.
        Reveal(
          controller: _entrance,
          begin: 0.3,
          end: 0.7,
          child: const WelcomeBenefit(
            icon: Icons.verified_user_outlined,
            label: 'Verified\nCaregivers',
            iconColor: CareColors.primary,
            backdrop: CareColors.primarySoft,
          ),
        ),
        SizedBox(height: gap(8, 12)),
        Reveal(
          controller: _entrance,
          begin: 0.38,
          end: 0.78,
          child: const WelcomeBenefit(
            icon: Icons.favorite_border,
            label: 'Safe &\nReliable',
            iconColor: CareColors.accentWarm,
            backdrop: CareColors.accentWarmSoft,
          ),
        ),
        SizedBox(height: gap(8, 12)),
        Reveal(
          controller: _entrance,
          begin: 0.46,
          end: 0.86,
          child: const WelcomeBenefit(
            icon: Icons.groups_2_outlined,
            label: 'Personalized\nCare Plans',
            iconColor: CareColors.accentBlue,
            backdrop: CareColors.accentBlueSoft,
          ),
        ),
        // Room for the wave's curves to rise before the controls.
        SizedBox(height: waveZone),
      ],
    );
  }

  Widget _buildControls(double bottomInset) {
    return Reveal(
      controller: _entrance,
      begin: 0.55,
      end: 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(CareSpacing.screenH, 0, CareSpacing.screenH, 10 + bottomInset),
        child: Column(
          children: [
            const SizedBox(height: 10, child: OnboardingDots(index: 0, count: caregiverOnboardingStepCount)),
            const SizedBox(height: 20),
            CarePrimaryCta(label: 'Get Started', onPressed: _getStarted),
            const SizedBox(height: 6),
            SizedBox(
              height: CareSizes.minTouch,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Already have an account?', style: TextStyle(fontSize: 16.5, color: Colors.white.withValues(alpha: 0.92))),
                    TextButton(
                      onPressed: _signIn,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(64, CareSizes.minTouch),
                        // The app theme's comfortable density would shave this below 48dp.
                        visualDensity: VisualDensity.standard,
                        padding: const EdgeInsets.symmetric(horizontal: CareSpacing.md),
                        textStyle: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Sign In'),
                    ),
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
