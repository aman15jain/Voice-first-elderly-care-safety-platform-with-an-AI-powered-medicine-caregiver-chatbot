import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/daily_activity.dart';

class ActivityRepository {
  ActivityRepository(this._dio);
  final Dio _dio;

  Future<List<DailyActivity>> weeklySummary() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/activity/summary');
    return (res.data!['days'] as List).map((e) => DailyActivity.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Best-effort, fire-and-forget: never blocks the UI and never surfaces an error —
  /// see features/home, which calls this once per app open.
  Future<void> recordAppOpened() async {
    try {
      await _dio.post<void>('/api/activity/app-opened');
    } catch (_) {
      // Non-critical: a missed engagement ping is not worth bothering the elder about.
    }
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) => ActivityRepository(ref.watch(dioProvider)));

final weeklyActivityProvider = FutureProvider.autoDispose<List<DailyActivity>>((ref) {
  return ref.watch(activityRepositoryProvider).weeklySummary();
});
