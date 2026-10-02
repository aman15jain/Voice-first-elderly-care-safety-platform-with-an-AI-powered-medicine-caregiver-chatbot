import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOnline(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

/// A concrete, injectable wrapper around `connectivity_plus` — same device-capability
/// pattern as `LocationService`/`PhoneService` (Phase 6/7): tests override it with a fake
/// rather than touching the real platform channel.
///
/// Connectivity here means "the device has a network interface up" (Wi-Fi/mobile data), not
/// "the backend is reachable" — a captive portal or a down server still counts as "online" by
/// this signal. API calls can still fail; this only drives the offline *indicator*, not a
/// guarantee requests will succeed.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  Future<bool> isOnlineNow() async => _isOnline(await _connectivity.checkConnectivity());

  Stream<bool> onlineStream() => _connectivity.onConnectivityChanged.map(_isOnline);
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());

/// `true` once we have a connectivity reading; starts by checking the current state, then
/// follows live changes. Screens/widgets watch this instead of talking to the plugin directly.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOnlineNow();
  yield* service.onlineStream();
});
