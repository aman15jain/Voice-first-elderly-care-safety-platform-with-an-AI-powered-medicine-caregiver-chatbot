enum FamilyLinkStatus { pending, accepted, declined, revoked }

FamilyLinkStatus familyLinkStatusFromString(String value) {
  switch (value) {
    case 'PENDING':
      return FamilyLinkStatus.pending;
    case 'ACCEPTED':
      return FamilyLinkStatus.accepted;
    case 'DECLINED':
      return FamilyLinkStatus.declined;
    default:
      return FamilyLinkStatus.revoked;
  }
}

class FamilyLink {
  const FamilyLink({
    required this.id,
    required this.elderId,
    required this.caregiverId,
    required this.invitedBy,
    required this.status,
    required this.elderEmail,
    required this.caregiverEmail,
    this.elderName,
    this.caregiverName,
  });

  final String id;
  final String elderId;
  final String caregiverId;
  final String invitedBy;
  final FamilyLinkStatus status;
  final String? elderName;
  final String elderEmail;
  final String? caregiverName;
  final String caregiverEmail;

  factory FamilyLink.fromJson(Map<String, dynamic> json) => FamilyLink(
    id: json['id'] as String,
    elderId: json['elderId'] as String,
    caregiverId: json['caregiverId'] as String,
    invitedBy: json['invitedBy'] as String,
    status: familyLinkStatusFromString(json['status'] as String),
    elderName: json['elderName'] as String?,
    elderEmail: json['elderEmail'] as String,
    caregiverName: json['caregiverName'] as String?,
    caregiverEmail: json['caregiverEmail'] as String,
  );

  /// The name/email to show for "the other person" from [viewerId]'s point of view.
  String counterpartLabel(String viewerId) {
    final isViewerElder = viewerId == elderId;
    final name = isViewerElder ? caregiverName : elderName;
    final email = isViewerElder ? caregiverEmail : elderEmail;
    return (name?.trim().isNotEmpty == true) ? name! : email;
  }

  bool isInvitedParty(String viewerId) => invitedBy == elderId ? viewerId == caregiverId : viewerId == elderId;
}
