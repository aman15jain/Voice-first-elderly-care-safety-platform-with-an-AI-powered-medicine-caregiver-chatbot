/// The one action type this screen is allowed to execute from a voice response — see
/// VoiceScreen._executeAction. Any other `type` string is safely ignored rather than acted on.
class VoiceAction {
  const VoiceAction({required this.type, this.contactId, this.contactName, this.phone});

  final String type;
  final String? contactId;
  final String? contactName;
  final String? phone;

  factory VoiceAction.fromJson(Map<String, dynamic> json) => VoiceAction(
    type: json['type'] as String,
    contactId: json['contactId'] as String?,
    contactName: json['contactName'] as String?,
    phone: json['phone'] as String?,
  );
}

class VoiceProcessResult {
  const VoiceProcessResult({required this.type, required this.response, required this.language, this.action});

  final String type;
  final String response;
  final String language;
  final VoiceAction? action;

  factory VoiceProcessResult.fromJson(Map<String, dynamic> json) => VoiceProcessResult(
    type: json['type'] as String,
    response: json['response'] as String,
    language: json['language'] as String,
    action: json['action'] == null ? null : VoiceAction.fromJson(json['action'] as Map<String, dynamic>),
  );
}
