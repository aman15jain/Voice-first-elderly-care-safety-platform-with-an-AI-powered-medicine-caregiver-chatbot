import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/voice_models.dart';

class VoiceRepository {
  VoiceRepository(this._dio);
  final Dio _dio;

  Future<VoiceProcessResult> process(String transcript, {String? language}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/voice/process',
      data: {'transcript': transcript, 'language': ?language},
    );
    return VoiceProcessResult.fromJson(res.data!);
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) => VoiceRepository(ref.watch(dioProvider)));
