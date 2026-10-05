import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// The AI-written caregiver insight for one elder, as returned by the backend.
///
/// The text is produced by the existing agentic-ai service (via Node), which grounds it in
/// the elder's own care records; the app only displays it and never computes or adds figures.
class CaregiverInsight {
  const CaregiverInsight({required this.response, required this.sources});

  final String response;
  final List<String> sources;

  factory CaregiverInsight.fromJson(Map<String, dynamic> json) =>
      CaregiverInsight(response: json['response'] as String, sources: ((json['sources'] as List?) ?? const []).cast<String>());
}

/// Entry points into the existing AI pipeline (Flutter → Node → agentic-ai). No AI logic
/// lives in the app.
class AiRepository {
  AiRepository(this._dio);
  final Dio _dio;

  Future<CaregiverInsight> getCaregiverInsight(String elderId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/ai/caregiver-insight', queryParameters: {'elderId': elderId});
    return CaregiverInsight.fromJson(res.data!);
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository(ref.watch(dioProvider)));
