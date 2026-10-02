enum EmergencyEventStatus { active, acknowledged, resolved }

EmergencyEventStatus emergencyEventStatusFromString(String value) {
  switch (value) {
    case 'ACTIVE':
      return EmergencyEventStatus.active;
    case 'ACKNOWLEDGED':
      return EmergencyEventStatus.acknowledged;
    default:
      return EmergencyEventStatus.resolved;
  }
}

class EmergencyEvent {
  const EmergencyEvent({
    required this.id,
    required this.elderId,
    required this.status,
    required this.triggeredAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String elderId;
  final EmergencyEventStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime triggeredAt;

  bool get isActive => status != EmergencyEventStatus.resolved;

  factory EmergencyEvent.fromJson(Map<String, dynamic> json) => EmergencyEvent(
    id: json['id'] as String,
    elderId: json['elderId'] as String,
    status: emergencyEventStatusFromString(json['status'] as String),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    triggeredAt: DateTime.parse(json['triggeredAt'] as String).toLocal(),
  );
}
