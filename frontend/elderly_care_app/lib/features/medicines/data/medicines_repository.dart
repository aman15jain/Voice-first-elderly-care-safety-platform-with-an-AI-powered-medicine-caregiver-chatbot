import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/medicine_models.dart';

String _dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Elder-facing calls act on the signed-in elder. The read calls also take an optional
/// [elderId] so a caregiver can view a linked elder's data — the backend's elder-scope check
/// (`resolveElderScope`) requires it for caregivers and enforces the accepted family link.
class MedicinesRepository {
  MedicinesRepository(this._dio);
  final Dio _dio;

  Future<List<Medicine>> listMedicines({String? elderId}) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/medicines', queryParameters: {'elderId': ?elderId});
    return (res.data!['medicines'] as List).map((e) => Medicine.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Medicine> createMedicine({required String name, required String dosage, String? instructions}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/medicines',
      data: {'name': name, 'dosage': dosage, if (instructions != null && instructions.isNotEmpty) 'instructions': instructions},
    );
    return Medicine.fromJson(res.data!['medicine'] as Map<String, dynamic>);
  }

  Future<void> deleteMedicine(String id) => _dio.delete<void>('/api/medicines/$id');

  Future<MedicineSchedule> createSchedule({
    required String medicineId,
    required List<String> timesOfDay,
    List<int> daysOfWeek = const [],
    required DateTime startDate,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/medicine-schedules',
      data: {'medicineId': medicineId, 'timesOfDay': timesOfDay, 'daysOfWeek': daysOfWeek, 'startDate': _dateOnly(startDate)},
    );
    return MedicineSchedule.fromJson(res.data!['schedule'] as Map<String, dynamic>);
  }

  Future<List<MedicineSchedule>> listSchedules({String? medicineId}) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/medicine-schedules', queryParameters: {'medicineId': ?medicineId});
    return (res.data!['schedules'] as List).map((e) => MedicineSchedule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MedicineDose>> listDoses({DateTime? from, DateTime? to, String? elderId}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/doses',
      queryParameters: {if (from != null) 'from': _dateOnly(from), if (to != null) 'to': _dateOnly(to), 'elderId': ?elderId},
    );
    return (res.data!['doses'] as List).map((e) => MedicineDose.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markReminded(String doseId) => _dio.post<void>('/api/doses/$doseId/reminded');
  Future<void> markTaken(String doseId) => _dio.post<void>('/api/adherence/$doseId/taken');
  Future<void> markSkipped(String doseId) => _dio.post<void>('/api/adherence/$doseId/skipped');

  Future<AdherenceSummary> adherenceSummary({DateTime? from, DateTime? to}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/adherence/summary',
      queryParameters: {if (from != null) 'from': _dateOnly(from), if (to != null) 'to': _dateOnly(to)},
    );
    return AdherenceSummary.fromJson(res.data!['summary'] as Map<String, dynamic>);
  }
}

final medicinesRepositoryProvider = Provider<MedicinesRepository>((ref) => MedicinesRepository(ref.watch(dioProvider)));
