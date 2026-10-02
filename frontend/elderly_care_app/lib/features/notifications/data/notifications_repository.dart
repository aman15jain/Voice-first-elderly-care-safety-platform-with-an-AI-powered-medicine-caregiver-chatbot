import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/notifications', queryParameters: {if (unreadOnly) 'unreadOnly': 'true'});
    return (res.data!['notifications'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(String id) => _dio.patch<void>('/api/notifications/$id/read');
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(dioProvider)));
