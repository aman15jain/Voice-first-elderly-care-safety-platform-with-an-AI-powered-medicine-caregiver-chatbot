import 'package:elderly_care_app/features/family/domain/family_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final link = FamilyLink(
    id: 'link-1',
    elderId: 'elder-1',
    caregiverId: 'caregiver-1',
    invitedBy: 'caregiver-1',
    status: FamilyLinkStatus.pending,
    elderName: 'Grandma Rose',
    elderEmail: 'rose@example.com',
    caregiverName: null,
    caregiverEmail: 'alex@example.com',
  );

  test('counterpartLabel shows the other party, preferring name over email', () {
    expect(link.counterpartLabel('elder-1'), 'alex@example.com'); // caregiver has no name
    expect(link.counterpartLabel('caregiver-1'), 'Grandma Rose');
  });

  test('isInvitedParty is true only for the party who did not send the invite', () {
    expect(link.isInvitedParty('caregiver-1'), isFalse); // the inviter
    expect(link.isInvitedParty('elder-1'), isTrue); // the invited party
  });

  test('familyLinkStatusFromString round-trips known values and falls back to revoked', () {
    expect(familyLinkStatusFromString('PENDING'), FamilyLinkStatus.pending);
    expect(familyLinkStatusFromString('ACCEPTED'), FamilyLinkStatus.accepted);
    expect(familyLinkStatusFromString('DECLINED'), FamilyLinkStatus.declined);
    expect(familyLinkStatusFromString('REVOKED'), FamilyLinkStatus.revoked);
    expect(familyLinkStatusFromString('anything-else'), FamilyLinkStatus.revoked);
  });
}
