import 'package:elderly_care_app/app.dart';
import 'package:elderly_care_app/core/services/connectivity_service.dart';
import 'package:elderly_care_app/core/services/location_service.dart';
import 'package:elderly_care_app/core/services/voice_input_service.dart';
import 'package:elderly_care_app/core/services/voice_output_service.dart';
import 'package:elderly_care_app/core/storage/local_cache.dart';
import 'package:elderly_care_app/core/storage/token_storage.dart';
import 'package:elderly_care_app/features/activity/data/activity_repository.dart';
import 'package:elderly_care_app/features/auth/data/auth_repository.dart';
import 'package:elderly_care_app/features/dashboard/data/dashboard_repository.dart';
import 'package:elderly_care_app/features/emergency/data/emergency_repository.dart';
import 'package:elderly_care_app/features/family/data/family_repository.dart';
import 'package:elderly_care_app/features/games/data/games_repository.dart';
import 'package:elderly_care_app/features/medicines/data/medicines_repository.dart';
import 'package:elderly_care_app/features/notifications/data/notifications_repository.dart';
import 'package:elderly_care_app/features/voice/data/voice_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_data_repositories.dart';
import '../fakes/fake_location_service.dart';
import '../fakes/fake_offline_infra.dart';
import '../fakes/fake_voice_services.dart';
import '../fakes/in_memory_secure_store.dart';

typedef TestHarness = ({
  FakeAuthRepository auth,
  FakeMedicinesRepository medicines,
  FakeFamilyRepository family,
  FakeGamesRepository games,
  FakeActivityRepository activity,
  FakeEmergencyRepository emergency,
  FakeVoiceRepository voice,
  FakeVoiceInputService voiceInput,
  FakeVoiceOutputService voiceOutput,
  FakeDashboardRepository dashboard,
  FakeNotificationsRepository notifications,
  FakeConnectivityService connectivity,
});

/// Pumps the full app with every network-touching repository replaced by an in-memory
/// fake, so router/auth-bootstrap/navigation wiring can be tested without a live backend.
Future<TestHarness> pumpApp(WidgetTester tester) async {
  // flutter_test's default surface (800x600, landscape-ish) does not match this app's
  // phone-only layouts: bottom-of-screen buttons on Home ended up obscured by the bottom
  // nav bar and taps silently hit the wrong tab instead. Use a realistic phone viewport.
  tester.view.physicalSize = const Size(480, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final tokenStorage = TokenStorage(InMemorySecureStore());
  final harness = (
    auth: FakeAuthRepository(tokenStorage),
    medicines: FakeMedicinesRepository(),
    family: FakeFamilyRepository(),
    games: FakeGamesRepository(),
    activity: FakeActivityRepository(),
    emergency: FakeEmergencyRepository(),
    voice: FakeVoiceRepository(),
    voiceInput: FakeVoiceInputService(),
    voiceOutput: FakeVoiceOutputService(),
    dashboard: FakeDashboardRepository(),
    notifications: FakeNotificationsRepository(),
    connectivity: FakeConnectivityService(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(harness.auth),
        medicinesRepositoryProvider.overrideWithValue(harness.medicines),
        familyRepositoryProvider.overrideWithValue(harness.family),
        gamesRepositoryProvider.overrideWithValue(harness.games),
        activityRepositoryProvider.overrideWithValue(harness.activity),
        emergencyRepositoryProvider.overrideWithValue(harness.emergency),
        locationServiceProvider.overrideWithValue(const FakeLocationService()),
        voiceRepositoryProvider.overrideWithValue(harness.voice),
        voiceInputServiceProvider.overrideWithValue(harness.voiceInput),
        voiceOutputServiceProvider.overrideWithValue(harness.voiceOutput),
        dashboardRepositoryProvider.overrideWithValue(harness.dashboard),
        notificationsRepositoryProvider.overrideWithValue(harness.notifications),
        connectivityServiceProvider.overrideWithValue(harness.connectivity),
        localCacheProvider.overrideWithValue(LocalCache(InMemoryKeyValueStore())),
      ],
      child: const ElderlyCareApp(),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}
