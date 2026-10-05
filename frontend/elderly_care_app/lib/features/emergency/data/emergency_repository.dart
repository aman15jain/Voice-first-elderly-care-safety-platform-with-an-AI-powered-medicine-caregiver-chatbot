import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/emergency_contact.dart';
import '../domain/emergency_event.dart';

class SosResult {
  const SosResult({required this.event, required this.contacts});
  final EmergencyEvent event;
  final List<EmergencyContact> contacts;
}

class EmergencyRepository {
  EmergencyRepository(this._dio);
  final Dio _dio;

  Future<List<EmergencyContact>> listContacts() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/emergency/contacts');
    return (res.data!['contacts'] as List).map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EmergencyContact> createContact({required String name, required String phone, String? relationship}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/emergency/contacts',
      data: {'name': name, 'phone': phone, if (relationship != null && relationship.isNotEmpty) 'relationship': relationship},
    );
    return EmergencyContact.fromJson(res.data!['contact'] as Map<String, dynamic>);
  }

  Future<void> deleteContact(String id) => _dio.delete<void>('/api/emergency/contacts/$id');

  /// Triggers SOS (idempotent server-side — a repeated press while one is already active
  /// just returns that same event) and hands back the contact list so the caller can
  /// immediately offer to call one, without a second round trip.
  Future<SosResult> triggerSOS({double? latitude, double? longitude}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/emergency/sos',
      data: {if (latitude != null && longitude != null) 'latitude': latitude, if (latitude != null && longitude != null) 'longitude': longitude},
    );
    return SosResult(
      event: EmergencyEvent.fromJson(res.data!['event'] as Map<String, dynamic>),
      contacts: (res.data!['contacts'] as List).map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<EmergencyEvent>> listEvents({String? elderId}) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/emergency/events', queryParameters: {'elderId': ?elderId});
    return (res.data!['events'] as List).map((e) => EmergencyEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acknowledge(String eventId) => _dio.patch<void>('/api/emergency/events/$eventId/acknowledge');
  Future<void> resolve(String eventId) => _dio.patch<void>('/api/emergency/events/$eventId/resolve');
}

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) => EmergencyRepository(ref.watch(dioProvider)));

final emergencyContactsProvider = FutureProvider.autoDispose<List<EmergencyContact>>((ref) {
  return ref.watch(emergencyRepositoryProvider).listContacts();
});

final emergencyEventsProvider = FutureProvider.autoDispose<List<EmergencyEvent>>((ref) {
  return ref.watch(emergencyRepositoryProvider).listEvents();
});

/// The most recent event, if it's still active — for showing "emergency in progress" state.
final activeEmergencyEventProvider = FutureProvider.autoDispose<EmergencyEvent?>((ref) async {
  final events = await ref.watch(emergencyEventsProvider.future);
  if (events.isEmpty || !events.first.isActive) return null;
  return events.first;
});
