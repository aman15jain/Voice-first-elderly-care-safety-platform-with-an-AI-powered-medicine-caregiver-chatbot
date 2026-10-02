import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

typedef Coordinates = ({double latitude, double longitude});

/// Best-effort, one-shot location capture for SOS — never blocks the SOS itself. See
/// docs/architecture.md: there is no background/continuous location tracking, only this
/// single read at the moment the elder presses the button.
class LocationService {
  const LocationService();

  Future<Coordinates?> getCurrentLocationOrNull() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      // Any failure here (permission, timeout, disabled service, unsupported platform)
      // just means the SOS goes out without a location — it must never block on this.
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());
