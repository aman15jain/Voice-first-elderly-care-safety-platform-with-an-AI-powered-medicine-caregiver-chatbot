import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/family_link.dart';

class FamilyRepository {
  FamilyRepository(this._dio);
  final Dio _dio;

  Future<List<FamilyLink>> listLinks() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/family/links');
    return (res.data!['links'] as List).map((e) => FamilyLink.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> invite(String email) => _dio.post<void>('/api/family/links', data: {'email': email});
  Future<void> accept(String linkId) => _dio.patch<void>('/api/family/links/$linkId/accept');
  Future<void> decline(String linkId) => _dio.patch<void>('/api/family/links/$linkId/decline');
  Future<void> revoke(String linkId) => _dio.delete<void>('/api/family/links/$linkId');
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) => FamilyRepository(ref.watch(dioProvider)));
