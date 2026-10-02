class EmergencyContact {
  const EmergencyContact({required this.id, required this.name, required this.phone, required this.priority, this.relationship});

  final String id;
  final String name;
  final String phone;
  final String? relationship;
  final int priority;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    relationship: json['relationship'] as String?,
    priority: json['priority'] as int,
  );
}
