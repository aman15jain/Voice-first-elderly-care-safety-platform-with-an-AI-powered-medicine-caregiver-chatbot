import 'package:elderly_care_app/core/services/location_service.dart';

/// Avoids touching the real geolocator platform channel in tests, which has no handler
/// registered and hangs `pumpAndSettle` forever rather than throwing.
class FakeLocationService extends LocationService {
  const FakeLocationService();

  @override
  Future<Coordinates?> getCurrentLocationOrNull() async => null;
}
