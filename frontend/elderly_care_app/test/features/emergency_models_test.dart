import 'package:elderly_care_app/features/emergency/domain/emergency_contact.dart';
import 'package:elderly_care_app/features/emergency/domain/emergency_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EmergencyContact.fromJson parses an optional relationship', () {
    final withRel = EmergencyContact.fromJson({'id': 'c1', 'name': 'Jane', 'phone': '555-1234', 'relationship': 'Daughter', 'priority': 1});
    expect(withRel.relationship, 'Daughter');
    final withoutRel = EmergencyContact.fromJson({'id': 'c2', 'name': 'Bob', 'phone': '555-5678', 'priority': 2});
    expect(withoutRel.relationship, isNull);
  });

  test('emergencyEventStatusFromString maps every backend status', () {
    expect(emergencyEventStatusFromString('ACTIVE'), EmergencyEventStatus.active);
    expect(emergencyEventStatusFromString('ACKNOWLEDGED'), EmergencyEventStatus.acknowledged);
    expect(emergencyEventStatusFromString('RESOLVED'), EmergencyEventStatus.resolved);
  });

  test('EmergencyEvent.isActive is false only once resolved', () {
    final active = EmergencyEvent.fromJson({'id': 'e1', 'elderId': 'elder1', 'status': 'ACTIVE', 'triggeredAt': '2026-01-01T08:00:00.000Z'});
    final resolved = EmergencyEvent.fromJson({'id': 'e2', 'elderId': 'elder1', 'status': 'RESOLVED', 'triggeredAt': '2026-01-01T08:00:00.000Z'});
    expect(active.isActive, isTrue);
    expect(resolved.isActive, isFalse);
  });

  test('EmergencyEvent.fromJson parses optional location', () {
    final event = EmergencyEvent.fromJson({
      'id': 'e1',
      'elderId': 'elder1',
      'status': 'ACTIVE',
      'latitude': 12.97,
      'longitude': 77.59,
      'triggeredAt': '2026-01-01T08:00:00.000Z',
    });
    expect(event.latitude, 12.97);
    expect(event.longitude, 77.59);
  });
}
