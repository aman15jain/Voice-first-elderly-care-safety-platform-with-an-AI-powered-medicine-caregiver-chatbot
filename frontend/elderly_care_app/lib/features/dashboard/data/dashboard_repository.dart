import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/elder_dashboard_row.dart';

class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  Future<List<ElderDashboardRow>> getDashboard() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/family/dashboard');
    return (res.data!['elders'] as List).map((e) => ElderDashboardRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DailyAdherencePoint>> getAdherenceTrend(String elderId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/adherence/trend', queryParameters: {'elderId': elderId});
    return (res.data!['days'] as List).map((e) => DailyAdherencePoint.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(dioProvider)));
