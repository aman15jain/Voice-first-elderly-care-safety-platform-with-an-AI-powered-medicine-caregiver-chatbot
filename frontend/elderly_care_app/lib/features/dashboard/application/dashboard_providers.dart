import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../domain/elder_dashboard_row.dart';

final caregiverDashboardProvider = FutureProvider.autoDispose<List<ElderDashboardRow>>((ref) {
  return ref.watch(dashboardRepositoryProvider).getDashboard();
});

/// Keyed per elder so each dashboard card fetches its own trend independently.
final adherenceTrendProvider = FutureProvider.family.autoDispose<List<DailyAdherencePoint>, String>((ref, elderId) {
  return ref.watch(dashboardRepositoryProvider).getAdherenceTrend(elderId);
});
