import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/activity/data/activity_repository.dart';
import '../errors/app_failure.dart';
import '../storage/local_cache.dart';

/// Queues exactly one kind of event: the non-critical "app opened" ping
/// (`ActivityRepository.recordAppOpened`), which is both safe to retry (idempotent per day
/// server-side) and safe to lose (it only feeds an activity summary, nothing safety-critical).
/// Nothing else in the app is queued — adherence actions and SOS always require a confirmed
/// live round trip, never a silent background retry; see docs/architecture.md.
class SyncQueueService {
  SyncQueueService(this._activityRepo, this._cache);
  final ActivityRepository _activityRepo;
  final LocalCache _cache;

  Future<void> recordAppOpenedWithQueue() async {
    try {
      await _activityRepo.recordAppOpened();
    } catch (e) {
      if (AppFailure.isNetworkError(e)) {
        await _cache.queuePendingAppOpened(DateTime.now());
      }
      // A real 4xx/5xx (not a connectivity issue) is swallowed here exactly as the pre-Phase-11
      // best-effort call already did — this ping was never allowed to interrupt the home screen.
    }
  }

  /// Called when connectivity transitions back to online. Retrying once is enough: the
  /// server-side idempotency means a retry that lands today still counts, and if it fails
  /// again (server still down) the entry stays queued for the next reconnect.
  Future<void> flushPending() async {
    final pending = await _cache.pendingAppOpenedDays();
    if (pending.isEmpty) return;
    try {
      await _activityRepo.recordAppOpened();
      await _cache.clearPendingAppOpened();
    } catch (_) {
      // Still unreachable — leave it queued rather than losing track of it.
    }
  }
}

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService(ref.watch(activityRepositoryProvider), ref.watch(localCacheProvider));
});
