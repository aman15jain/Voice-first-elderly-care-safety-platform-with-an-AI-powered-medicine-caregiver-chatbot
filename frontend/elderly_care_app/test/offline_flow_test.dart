import 'package:elderly_care_app/core/services/sync_queue_service.dart';
import 'package:elderly_care_app/core/storage/local_cache.dart';
import 'package:elderly_care_app/features/medicines/application/medicines_providers.dart';
import 'package:elderly_care_app/features/medicines/data/medicines_repository.dart';
import 'package:elderly_care_app/features/medicines/domain/medicine_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_data_repositories.dart';
import 'fakes/fake_offline_infra.dart';
import 'helpers/pump_app.dart';

Future<void> _loginAsElder(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'elder@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'correct-horse-1');
  await tester.tap(find.text('Log In'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the offline banner appears when connectivity drops and disappears when it returns', (tester) async {
    final harness = await pumpApp(tester);
    await _loginAsElder(tester);

    expect(find.textContaining("You're offline"), findsNothing);

    harness.connectivity.setOnline(false);
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsOneWidget);

    harness.connectivity.setOnline(true);
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets("todayScheduleProvider falls back to the cached copy when the network is unreachable, after a prior successful fetch", (tester) async {
    final medicines = FakeMedicinesRepository();
    medicines.medicinesToReturn = [const Medicine(id: 'm1', name: 'Metformin', dosage: '500mg', isActive: true)];
    medicines.dosesToReturn = [MedicineDose(id: 'd1', medicineId: 'm1', scheduledFor: DateTime.now(), status: DoseStatus.scheduled)];
    final cache = LocalCache(InMemoryKeyValueStore());

    AsyncValue<List<DoseView>>? latest;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [medicinesRepositoryProvider.overrideWithValue(medicines), localCacheProvider.overrideWithValue(cache)],
        child: Consumer(
          builder: (context, ref, _) {
            latest = ref.watch(todayScheduleProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(latest!.value!.single.medicineName, 'Metformin');

    medicines.throwNetworkErrorOnFetch = true;
    // Re-pump a fresh ProviderScope (equivalent to the app restarting while offline) sharing
    // the same cache instance, rather than invalidating in place — avoids relying on exactly
    // when Riverpod's scheduler ticks a disposal/refresh, which this version only does
    // reliably across a widget rebuild, not a bare `ProviderContainer.invalidate`.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [medicinesRepositoryProvider.overrideWithValue(medicines), localCacheProvider.overrideWithValue(cache)],
        child: Consumer(
          builder: (context, ref, _) {
            latest = ref.watch(todayScheduleProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(latest!.value!.single.medicineName, 'Metformin');
  });

  test('SyncQueueService queues the app-opened ping on a network failure, and flushes it once connectivity returns', () async {
    final activity = FakeActivityRepository();
    final cache = LocalCache(InMemoryKeyValueStore());
    final service = SyncQueueService(activity, cache);

    activity.throwNetworkErrorOnAppOpened = true;
    await service.recordAppOpenedWithQueue();
    expect(activity.appOpenedCallCount, 0);
    expect(await cache.pendingAppOpenedDays(), isNotEmpty);

    activity.throwNetworkErrorOnAppOpened = false;
    await service.flushPending();
    expect(activity.appOpenedCallCount, 1);
    expect(await cache.pendingAppOpenedDays(), isEmpty);
  });

  test('SyncQueueService does not queue a non-network error (a real 4xx/5xx)', () async {
    final activity = _ThrowingNonNetworkActivityRepository();
    final cache = LocalCache(InMemoryKeyValueStore());
    final service = SyncQueueService(activity, cache);

    await service.recordAppOpenedWithQueue();
    expect(await cache.pendingAppOpenedDays(), isEmpty);
  });
}

class _ThrowingNonNetworkActivityRepository extends FakeActivityRepository {
  @override
  Future<void> recordAppOpened() async => throw Exception('unexpected server error');
}
