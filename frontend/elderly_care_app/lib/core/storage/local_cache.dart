import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin seam over SharedPreferences — same pattern as `SecureStore`/`TokenStorage` — so tests
/// swap in an in-memory implementation instead of hitting a real platform channel.
abstract class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<List<String>> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

class SharedPreferencesStore implements KeyValueStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<void> setString(String key, String value) async => (await _prefs).setString(key, value);

  @override
  Future<List<String>> getStringList(String key) async => (await _prefs).getStringList(key) ?? const [];

  @override
  Future<void> setStringList(String key, List<String> value) async => (await _prefs).setStringList(key, value);

  @override
  Future<void> remove(String key) async => (await _prefs).remove(key);
}

/// A cached read, with the fact that it's cached and when it was fetched never hidden from
/// the caller — screens using this must tell the user they're looking at possibly-stale data.
class CachedSchedule {
  const CachedSchedule({required this.doses, required this.cachedAt});
  final List<Map<String, dynamic>> doses;
  final DateTime cachedAt;
}

/// Only two offline concerns, kept deliberately small (spec section 11: don't over-engineer):
/// (1) today's medicine schedule, so an elder can still see what's due with no connection, and
/// (2) a tiny queue of non-critical "app opened" pings that failed to send, flushed once
/// connectivity returns. Nothing else in the app caches or queues — adherence actions
/// (taken/skipped) and SOS always require a live round trip; see docs/architecture.md.
class LocalCache {
  LocalCache(this._store);
  final KeyValueStore _store;

  static const _scheduleKey = 'cache.todays_schedule.v1';
  static const _scheduleCachedAtKey = 'cache.todays_schedule_cached_at.v1';
  static const _pendingAppOpenedKey = 'sync.pending_app_opened_days.v1';

  Future<void> saveTodaysSchedule(List<Map<String, dynamic>> doses) async {
    await _store.setString(_scheduleKey, jsonEncode(doses));
    await _store.setString(_scheduleCachedAtKey, DateTime.now().toIso8601String());
  }

  Future<CachedSchedule?> readTodaysSchedule() async {
    final raw = await _store.getString(_scheduleKey);
    final cachedAtRaw = await _store.getString(_scheduleCachedAtKey);
    if (raw == null || cachedAtRaw == null) return null;
    final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return CachedSchedule(doses: decoded, cachedAt: DateTime.parse(cachedAtRaw));
  }

  /// Idempotent: calling this twice for the same day (e.g. the app was opened offline twice)
  /// records the day once, matching the backend's own once-per-day semantics.
  Future<void> queuePendingAppOpened(DateTime day) async {
    final pending = await _store.getStringList(_pendingAppOpenedKey);
    final key = _dayKey(day);
    if (!pending.contains(key)) {
      await _store.setStringList(_pendingAppOpenedKey, [...pending, key]);
    }
  }

  Future<List<String>> pendingAppOpenedDays() => _store.getStringList(_pendingAppOpenedKey);

  Future<void> clearPendingAppOpened() => _store.remove(_pendingAppOpenedKey);

  static String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache(SharedPreferencesStore()));
