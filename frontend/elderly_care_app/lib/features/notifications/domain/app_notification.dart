enum AppNotificationType { missedDose, emergencySos }

AppNotificationType _typeFromString(String value) => value == 'EMERGENCY_SOS' ? AppNotificationType.emergencySos : AppNotificationType.missedDose;

class AppNotification {
  const AppNotification({required this.id, required this.type, required this.title, required this.body, required this.createdAt, this.readAt});

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    type: _typeFromString(json['type'] as String),
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
  );
}
