import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/domain/elder_dashboard_row.dart';
import '../../dashboard/presentation/adherence_sparkline.dart';

/// The real caregiver dashboard (Phase 10): one card per linked elder with a 30-day
/// adherence rate, a day-by-day trend, 7-day activity, and an emergency banner — all from
/// one call to GET /api/family/dashboard, never N requests for N elders.
class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final name = authState is AuthAuthenticated ? authState.user.displayName : '';
    final dashboard = ref.watch(caregiverDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [IconButton(icon: const Icon(Icons.person), onPressed: () => context.push('/caregiver/profile'))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $name', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              Expanded(
                child: dashboard.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(caregiverDashboardProvider)),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.diversity_3, size: 56),
                            const SizedBox(height: 12),
                            const Text('No elders linked yet.', style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 16),
                            FilledButton(onPressed: () => context.go('/caregiver/family'), child: const Text('Invite an Elder')),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(caregiverDashboardProvider),
                      child: ListView(
                        children: [
                          Text('Linked elders (${rows.length})', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          for (final row in rows) _ElderDashboardCard(row: row),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElderDashboardCard extends StatelessWidget {
  const _ElderDashboardCard({required this.row});
  final ElderDashboardRow row;

  @override
  Widget build(BuildContext context) {
    final rate = row.adherence.takenRate;
    final (rateLabel, rateColor) = rate == null ? ('No doses due yet', Colors.grey) : ('$rate% taken (30d)', _colorForRate(rate));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: row.activeEmergency ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (row.activeEmergency) ...[
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Active emergency — check the Alerts tab', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(row.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text(rateLabel), backgroundColor: rateColor.withValues(alpha: 0.15)),
                Chip(label: Text('${row.activity.activeDays}/${row.activity.daysInRange} active days')),
              ],
            ),
            const SizedBox(height: 12),
            AdherenceSparkline(elderId: row.elderId),
          ],
        ),
      ),
    );
  }

  Color _colorForRate(int rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 50) return Colors.orange;
    return Colors.red;
  }
}
