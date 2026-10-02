import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/health_status.dart';

class HealthRepository {
  HealthRepository(this._dio);
  final Dio _dio;

  /// Calls GET /health/dependencies. The backend answers 503 when a dependency is
  /// down, which is still a valid "backend reachable" response, so 503 is parsed too.
  /// Throws [DioException] only when the backend itself cannot be reached.
  Future<BackendHealth> check() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/health/dependencies',
      options: Options(validateStatus: (s) => s == 200 || s == 503),
    );
    final deps = (res.data?['dependencies'] as Map<String, dynamic>?) ?? const {};
    return BackendHealth(
      ok: true,
      database: _state(deps['database']),
      aiService: _state(deps['aiService']),
    );
  }

  DependencyState _state(Object? dep) {
    final status = dep is Map ? dep['status'] : null;
    return status == 'up' ? DependencyState.up : DependencyState.down;
  }
}

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(dioProvider)),
);

final backendHealthProvider = FutureProvider.autoDispose<BackendHealth>(
  (ref) => ref.watch(healthRepositoryProvider).check(),
);
