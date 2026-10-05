import 'package:dio/dio.dart';
import 'package:elderly_care_app/features/activity/data/activity_repository.dart';
import 'package:elderly_care_app/features/activity/domain/daily_activity.dart';
import 'package:elderly_care_app/features/ai/data/ai_repository.dart';
import 'package:elderly_care_app/features/dashboard/data/dashboard_repository.dart';
import 'package:elderly_care_app/features/dashboard/domain/elder_dashboard_row.dart';
import 'package:elderly_care_app/features/emergency/data/emergency_repository.dart';
import 'package:elderly_care_app/features/emergency/domain/emergency_contact.dart';
import 'package:elderly_care_app/features/emergency/domain/emergency_event.dart';
import 'package:elderly_care_app/features/family/data/family_repository.dart';
import 'package:elderly_care_app/features/family/domain/family_link.dart';
import 'package:elderly_care_app/features/games/data/games_repository.dart';
import 'package:elderly_care_app/features/games/domain/game_models.dart';
import 'package:elderly_care_app/features/medicines/data/medicines_repository.dart';
import 'package:elderly_care_app/features/medicines/domain/medicine_models.dart';
import 'package:elderly_care_app/features/notifications/data/notifications_repository.dart';
import 'package:elderly_care_app/features/notifications/domain/app_notification.dart';

/// Empty by default — enough for screens that only need "nothing due / nothing linked
/// yet" without a real backend.
class FakeMedicinesRepository extends MedicinesRepository {
  FakeMedicinesRepository() : super(Dio());

  List<Medicine> medicinesToReturn = const [];
  List<MedicineDose> dosesToReturn = const [];
  bool throwNetworkErrorOnFetch = false;

  /// The elderId of the most recent caregiver-scoped dose request (null for elder calls).
  String? lastDosesElderId;

  DioException _networkError() => DioException(
    requestOptions: RequestOptions(path: '/api/doses'),
    type: DioExceptionType.connectionError,
  );

  @override
  Future<List<Medicine>> listMedicines({String? elderId}) async {
    if (throwNetworkErrorOnFetch) throw _networkError();
    return medicinesToReturn;
  }

  @override
  Future<List<MedicineDose>> listDoses({DateTime? from, DateTime? to, String? elderId}) async {
    lastDosesElderId = elderId;
    if (throwNetworkErrorOnFetch) throw _networkError();
    return dosesToReturn;
  }

  @override
  Future<AdherenceSummary> adherenceSummary({DateTime? from, DateTime? to}) async =>
      const AdherenceSummary(from: '2026-01-01', to: '2026-01-30', scheduled: 0, reminded: 0, taken: 0, skipped: 0, missed: 0, totalDue: 0);
}

class FakeFamilyRepository extends FamilyRepository {
  FakeFamilyRepository() : super(Dio());

  @override
  Future<List<FamilyLink>> listLinks() async => [];
}

class FakeGamesRepository extends GamesRepository {
  FakeGamesRepository() : super(Dio());

  List<CognitiveGame> gamesToReturn = const [
    CognitiveGame(id: 'g1', type: GameType.memoryMatch, name: 'Memory Match', description: 'Find the pairs', suggestedDifficulty: 1),
    CognitiveGame(id: 'g2', type: GameType.patternRecognition, name: 'Pattern Recognition', description: 'What comes next', suggestedDifficulty: 1),
    CognitiveGame(id: 'g3', type: GameType.attentionExercise, name: 'Attention Exercise', description: 'Find the odd one', suggestedDifficulty: 1),
    CognitiveGame(id: 'g4', type: GameType.sequenceRecall, name: 'Sequence Recall', description: 'Repeat it back', suggestedDifficulty: 1),
  ];
  GameSessionResult? lastRecorded;

  @override
  Future<List<CognitiveGame>> listGames() async => gamesToReturn;

  @override
  Future<void> recordSession(String gameId, GameSessionResult result) async {
    lastRecorded = result;
  }
}

class FakeActivityRepository extends ActivityRepository {
  FakeActivityRepository() : super(Dio());

  List<DailyActivity> daysToReturn = const [];
  int appOpenedCallCount = 0;
  bool get appOpenedCalled => appOpenedCallCount > 0;
  bool throwNetworkErrorOnAppOpened = false;

  @override
  Future<List<DailyActivity>> weeklySummary() async => daysToReturn;

  @override
  Future<void> recordAppOpened() async {
    if (throwNetworkErrorOnAppOpened) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/activity/app-opened'),
        type: DioExceptionType.connectionError,
      );
    }
    appOpenedCallCount++;
  }
}

class FakeEmergencyRepository extends EmergencyRepository {
  FakeEmergencyRepository() : super(Dio());

  List<EmergencyContact> contactsToReturn = const [
    EmergencyContact(id: 'c1', name: 'Daughter Jane', phone: '555-123-4567', relationship: 'Daughter', priority: 1),
  ];
  List<EmergencyEvent> eventsToReturn = const [];
  ({double? latitude, double? longitude})? lastSosLocation;

  @override
  Future<List<EmergencyContact>> listContacts() async => contactsToReturn;

  @override
  Future<void> deleteContact(String id) async {
    contactsToReturn = contactsToReturn.where((c) => c.id != id).toList();
  }

  @override
  Future<EmergencyContact> createContact({required String name, required String phone, String? relationship}) async {
    final contact = EmergencyContact(
      id: 'new-${contactsToReturn.length + 1}',
      name: name,
      phone: phone,
      relationship: relationship,
      priority: contactsToReturn.length + 1,
    );
    contactsToReturn = [...contactsToReturn, contact];
    return contact;
  }

  @override
  Future<SosResult> triggerSOS({double? latitude, double? longitude}) async {
    lastSosLocation = (latitude: latitude, longitude: longitude);
    final event = EmergencyEvent(
      id: 'e1',
      elderId: 'elder1',
      status: EmergencyEventStatus.active,
      triggeredAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );
    eventsToReturn = [event];
    return SosResult(event: event, contacts: contactsToReturn);
  }

  @override
  Future<List<EmergencyEvent>> listEvents({String? elderId}) async => eventsToReturn;

  @override
  Future<void> resolve(String eventId) async {
    eventsToReturn = eventsToReturn.map((e) {
      if (e.id != eventId) return e;
      return EmergencyEvent(
        id: e.id,
        elderId: e.elderId,
        status: EmergencyEventStatus.resolved,
        triggeredAt: e.triggeredAt,
        latitude: e.latitude,
        longitude: e.longitude,
      );
    }).toList();
  }
}

class FakeDashboardRepository extends DashboardRepository {
  FakeDashboardRepository() : super(Dio());

  List<ElderDashboardRow> dashboardToReturn = const [];
  List<DailyAdherencePoint> trendToReturn = const [];
  Object? errorToThrow;

  @override
  Future<List<ElderDashboardRow>> getDashboard() async {
    if (errorToThrow != null) throw errorToThrow!;
    return dashboardToReturn;
  }

  @override
  Future<List<DailyAdherencePoint>> getAdherenceTrend(String elderId) async => trendToReturn;
}

class FakeNotificationsRepository extends NotificationsRepository {
  FakeNotificationsRepository() : super(Dio());

  List<AppNotification> notificationsToReturn = const [];
  String? lastMarkedReadId;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async => notificationsToReturn;

  @override
  Future<void> markRead(String id) async {
    lastMarkedReadId = id;
    notificationsToReturn = notificationsToReturn
        .map((n) => n.id == id ? AppNotification(id: n.id, type: n.type, title: n.title, body: n.body, createdAt: n.createdAt, readAt: DateTime.now()) : n)
        .toList();
  }
}

class FakeAiRepository extends AiRepository {
  FakeAiRepository() : super(Dio());

  CaregiverInsight insightToReturn = const CaregiverInsight(response: 'Medicines were taken on time this week.', sources: []);
  Object? errorToThrow;
  final requestedElderIds = <String>[];

  @override
  Future<CaregiverInsight> getCaregiverInsight(String elderId) async {
    requestedElderIds.add(elderId);
    if (errorToThrow != null) throw errorToThrow!;
    return insightToReturn;
  }
}
