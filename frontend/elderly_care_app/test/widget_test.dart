import 'package:dio/dio.dart';
import 'package:elderly_care_app/core/theme/app_theme.dart';
import 'package:elderly_care_app/features/health/data/health_repository.dart';
import 'package:elderly_care_app/features/health/domain/health_status.dart';
import 'package:elderly_care_app/features/health/presentation/health_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The Phase 1 connectivity check, still reachable at /diagnostics. Tested in isolation
// (not through the full app/router) since it has no auth or navigation dependencies.
class _FakeRepo extends HealthRepository {
  _FakeRepo(this._result) : super(Dio());
  final Future<BackendHealth> Function() _result;

  @override
  Future<BackendHealth> check() => _result();
}

Widget _harness(Future<BackendHealth> Function() result) => ProviderScope(
  overrides: [healthRepositoryProvider.overrideWithValue(_FakeRepo(result))],
  child: MaterialApp(theme: AppTheme.light(), home: const HealthScreen()),
);

void main() {
  testWidgets('shows all services working', (tester) async {
    await tester.pumpWidget(
      _harness(() async => const BackendHealth(ok: true, database: DependencyState.up, aiService: DependencyState.up)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Working'), findsNWidgets(3));
  });

  testWidgets('shows friendly message when the backend is unreachable', (tester) async {
    await tester.pumpWidget(_harness(() async => throw DioException(requestOptions: RequestOptions())));
    await tester.pumpAndSettle();
    expect(find.text('Not available'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
