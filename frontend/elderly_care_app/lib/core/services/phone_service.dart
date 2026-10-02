import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device's phone dialer — a real, on-device action, not a simulation. The
/// backend cannot place this call itself: an emergency contact is just a phone number,
/// not necessarily a registered user it has any other way to reach (docs/architecture.md).
class PhoneService {
  const PhoneService();

  Future<bool> call(String phoneNumber) {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    return launchUrl(uri);
  }
}

final phoneServiceProvider = Provider<PhoneService>((ref) => const PhoneService());
