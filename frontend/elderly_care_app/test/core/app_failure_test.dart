import 'package:dio/dio.dart';
import 'package:elderly_care_app/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _errorWith({int? status, Object? data}) => DioException(
  requestOptions: RequestOptions(path: '/api/x'),
  response: status == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: '/api/x'),
          statusCode: status,
          data: data,
        ),
);

void main() {
  test('passes through the backend message for a 4xx error', () {
    final failure = AppFailure.fromError(
      _errorWith(
        status: 409,
        data: {
          'error': {'code': 'CONFLICT', 'message': 'An account with this email already exists'},
        },
      ),
    );
    expect(failure.message, 'An account with this email already exists');
    expect(failure.code, 'CONFLICT');
  });

  test('never surfaces the backend message for a 5xx error', () {
    final failure = AppFailure.fromError(
      _errorWith(
        status: 500,
        data: {
          'error': {'code': 'INTERNAL_ERROR', 'message': 'db exploded'},
        },
      ),
    );
    expect(failure.message, isNot(contains('db exploded')));
  });

  test('gives a specific, actionable message when there is no response at all (network error)', () {
    final failure = AppFailure.fromError(_errorWith());
    expect(failure.message, isNotEmpty);
    expect(failure.message.toLowerCase(), isNot(contains('dioexception')));
    expect(failure.code, 'NETWORK_UNREACHABLE');
    expect(AppFailure.isNetworkError(_errorWith()), isTrue);
  });

  test('isNetworkError is false for a real server response, even a 5xx one', () {
    expect(AppFailure.isNetworkError(_errorWith(status: 500)), isFalse);
    expect(AppFailure.isNetworkError(Exception('not a DioException')), isFalse);
  });

  test('gives a generic message for a non-Dio error', () {
    final failure = AppFailure.fromError(Exception('some internal detail'));
    expect(failure.message, isNot(contains('some internal detail')));
  });
}
