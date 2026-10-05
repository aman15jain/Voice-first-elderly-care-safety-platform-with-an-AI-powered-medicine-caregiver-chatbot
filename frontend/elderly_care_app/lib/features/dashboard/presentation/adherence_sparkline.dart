import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/care_tokens.dart';
import '../application/dashboard_providers.dart';

/// A small, dependency-free bar chart: one bar per day, height proportional to that day's
/// taken-rate. A day with nothing due yet renders as a thin gray placeholder bar so the
/// trend still reads as "N days", not a gap.
class AdherenceSparkline extends ConsumerWidget {
  const AdherenceSparkline({super.key, required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(adherenceTrendProvider(elderId));
    return trend.when(
      loading: () => const SizedBox(height: 32),
      error: (_, _) => const SizedBox.shrink(),
      data: (days) {
        if (days.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: day.totalDue == 0 ? '${day.date}: nothing due' : '${day.date}: ${day.takenRate}% (${day.taken}/${day.totalDue})',
                      child: FractionallySizedBox(
                        heightFactor: day.totalDue == 0 ? 0.08 : (0.08 + 0.92 * ((day.takenRate ?? 0) / 100)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: day.totalDue == 0 ? CareColors.neutralSoft : _colorForRate(day.takenRate),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _colorForRate(int? rate) {
    if (rate == null) return CareColors.neutralSoft;
    if (rate >= 80) return CareColors.success;
    if (rate >= 50) return CareColors.accentWarm;
    return CareColors.danger;
  }
}
