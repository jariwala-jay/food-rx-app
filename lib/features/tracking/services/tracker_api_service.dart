import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/models/tracker_progress.dart';

/// Tracker CRUD via backend API.
class TrackerApiService {
  Future<List<TrackerGoal>> getTrackers(String userId,
      {String? dietType, bool? isWeeklyGoal}) async {
    final query = <String, String>{};
    if (dietType != null) query['dietType'] = dietType;
    if (isWeeklyGoal != null) query['isWeeklyGoal'] = isWeeklyGoal.toString();
    final list = await ApiClient.get('/trackers', queryParameters: query);
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((d) => TrackerGoal.fromJson(d))
        .toList();
  }

  Future<TrackerGoal?> getTracker(String trackerId) async {
    try {
      final doc = await ApiClient.get('/trackers/$trackerId')
          as Map<String, dynamic>?;
      if (doc == null) return null;
      return TrackerGoal.fromJson(doc);
    } catch (_) {
      return null;
    }
  }

  Future<TrackerGoal> createTracker(Map<String, dynamic> body) async {
    final doc = await ApiClient.post('/trackers', body: body)
        as Map<String, dynamic>?;
    if (doc == null) throw Exception('Create tracker returned null');
    return TrackerGoal.fromJson(doc);
  }

  Future<void> updateTracker(String trackerId, Map<String, dynamic> body) async {
    await ApiClient.patch('/trackers/$trackerId', body: body);
  }

  Future<void> deleteTracker(String trackerId) async {
    await ApiClient.delete('/trackers/$trackerId');
  }

  /// Save progress records (snapshot). Body: list of progress docs.
  Future<void> saveProgress(List<Map<String, dynamic>> docs) async {
    if (docs.isEmpty) return;
    await ApiClient.post('/trackers/progress', body: docs);
  }

  /// Get progress history. Optional: trackerId, periodType, startDate, endDate (ISO).
  Future<List<TrackerProgress>> getProgress({
    String? trackerId,
    String? periodType,
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, String>{};
    if (trackerId != null) query['trackerId'] = trackerId;
    if (periodType != null) query['periodType'] = periodType;
    if (startDate != null) query['startDate'] = startDate;
    if (endDate != null) query['endDate'] = endDate;
    final list = await ApiClient.get('/trackers/progress', queryParameters: query);
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((d) => TrackerProgress.fromJson(d))
        .toList();
  }
}
