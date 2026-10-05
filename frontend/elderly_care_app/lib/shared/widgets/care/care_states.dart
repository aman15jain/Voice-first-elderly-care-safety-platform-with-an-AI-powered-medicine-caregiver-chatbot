import 'package:flutter/material.dart';

import '../../../core/theme/care_tokens.dart';
import 'care_skeleton.dart';

/// The one empty-state layout for every screen:
/// soft icon tile → title → short explanation → optional primary action.
class CareEmptyState extends StatelessWidget {
  const CareEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.iconColor = CareColors.primary,
    this.iconBackground = CareColors.primarySoft,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    // Theme text styles, so the elder (comfort) theme gets its larger sizes automatically.
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CareSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: CareShadows.tile,
                ),
                child: Icon(icon, size: 42, color: iconColor),
              ),
              const SizedBox(height: CareSpacing.xl),
              Semantics(
                header: true,
                child: Text(title, style: text.titleLarge, textAlign: TextAlign.center),
              ),
              const SizedBox(height: CareSpacing.sm),
              Text(message, style: text.bodyMedium?.copyWith(height: 1.5), textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: CareSpacing.xl),
                FilledButton.icon(onPressed: onAction, icon: Icon(actionIcon ?? Icons.arrow_forward), label: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The one error-state layout for every screen. [message] must already be friendly
/// (from AppFailure) — never an exception, URL or stack trace.
class CareErrorState extends StatelessWidget {
  const CareErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return CareEmptyState(
      icon: Icons.cloud_off_outlined,
      iconColor: CareColors.accentWarm,
      iconBackground: CareColors.accentWarmSoft,
      title: 'Something went wrong',
      message: message,
      actionLabel: onRetry == null ? null : 'Try Again',
      actionIcon: Icons.refresh,
      onAction: onRetry,
    );
  }
}

/// Loading placeholder for list screens: a few soft card-shaped skeletons.
class CareListSkeleton extends StatelessWidget {
  const CareListSkeleton({super.key, this.count = 3, this.itemHeight = 112});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return CareSkeleton(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(CareSpacing.screenH - 4),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: CareSpacing.md),
        itemBuilder: (_, _) => CareSkeletonBlock(height: itemHeight, radius: CareRadius.card),
      ),
    );
  }
}

/// Inline form / action error: a soft red rounded banner with an icon, so validation and
/// server errors read the same on every form.
class CareInlineError extends StatelessWidget {
  const CareInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: CareSpacing.lg, vertical: CareSpacing.md),
        decoration: BoxDecoration(
          color: CareColors.dangerSoft,
          borderRadius: BorderRadius.circular(CareRadius.tile),
          border: Border.all(color: CareColors.dangerBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: CareColors.danger),
            const SizedBox(width: CareSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CareColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft informational banner (e.g. "showing saved data while offline").
class CareInfoBanner extends StatelessWidget {
  const CareInfoBanner({super.key, required this.message, this.icon = Icons.info_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, 0),
      padding: const EdgeInsets.symmetric(horizontal: CareSpacing.lg, vertical: CareSpacing.md),
      decoration: BoxDecoration(color: CareColors.infoSoft, borderRadius: BorderRadius.circular(CareRadius.tile)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CareColors.info),
          const SizedBox(width: CareSpacing.md),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CareColors.textDark)),
          ),
        ],
      ),
    );
  }
}

/// Small loading indicator for a section inside an already-scrolling page (where the
/// full-screen [CareListSkeleton] cannot be nested).
class CareInlineLoading extends StatelessWidget {
  const CareInlineLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: CareSpacing.xl),
    child: Center(child: CircularProgressIndicator()),
  );
}
