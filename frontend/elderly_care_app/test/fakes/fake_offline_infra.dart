import 'dart:async';

import 'package:elderly_care_app/core/services/connectivity_service.dart';
import 'package:elderly_care_app/core/storage/local_cache.dart';

/// Defaults to "online" so every existing test keeps behaving exactly as before unless a test
/// explicitly flips it — offline behavior is opt-in per test, not a global default.
class FakeConnectivityService implements ConnectivityService {
  bool online = true;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnlineNow() async => online;

  @override
  Stream<bool> onlineStream() => _controller.stream;
}

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  Future<List<String>> getStringList(String key) async => (_values[key] as List<String>?) ?? const [];

  @override
  Future<void> setStringList(String key, List<String> value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
