import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter_app/core/services/mongodb_service.dart';
import '../models/tracker_goal.dart';
import '../models/tracker_progress.dart';
import 'tracker_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_app/features/tracking/services/diet_plan_service.dart';

class TrackerService {
  final MongoDBService _mongoDBService;
  final TrackerProgressService _progressService;
  final DietPlanService _dietPlanService;
  static final TrackerService _instance = TrackerService._internal();

  List<TrackerGoal> _cachedDailyTrackers = [];
  List<TrackerGoal> _cachedWeeklyTrackers = [];
  bool _useLocalFallback = false;
  bool _isInitialized = false;

  factory TrackerService() => _instance;

  TrackerService._internal()
      : _mongoDBService = MongoDBService(),
        _progressService = TrackerProgressService(),
        _dietPlanService = DietPlanService();

  static const String _collectionName = 'user_trackers';

  Future<mongo.DbCollection?> get _collection async {
    try {
      await _ensureMongoConnection();
      if (_useLocalFallback) return null;
      return _mongoDBService.db.collection(_collectionName);
    } catch (e) {
      print('Failed to get collection: $e');
      _useLocalFallback = true;
      return null;
    }
  }

  Future<void> _ensureMongoConnection() async {
    try {
      if (!_isInitialized) {
        await _mongoDBService.initialize();
        _isInitialized = true;
      }
      if (_mongoDBService.db.state == mongo.State.closed) {
        await _mongoDBService.initialize();
        _isInitialized = true;
      }
      await _mongoDBService.ensureConnection();
      _useLocalFallback = false;
    } catch (e) {
      print('MongoDB connection failed, using local fallback: $e');
      _useLocalFallback = true;
      _isInitialized = false;
    }
  }

  final List<Map<String, dynamic>> _pendingUpdates = [];
  bool _isProcessingQueue = false;

  Future<void> _cacheTrackersLocally(List<TrackerGoal> daily,
      List<TrackerGoal> weekly, String userId, String dietType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dailyCacheKey = 'daily_trackers_${userId}_$dietType';
      final weeklyCacheKey = 'weekly_trackers_${userId}_$dietType';
      await prefs.setString(
          dailyCacheKey, jsonEncode(daily.map((t) => t.toJson()).toList()));
      await prefs.setString(
          weeklyCacheKey, jsonEncode(weekly.map((t) => t.toJson()).toList()));
      _cachedDailyTrackers = List.from(daily);
      _cachedWeeklyTrackers = List.from(weekly);
    } catch (e) {
      print('Failed to cache trackers locally: $e');
    }
  }

  Future<List<TrackerGoal>> _getLocalTrackers(
      String userId, String dietType, bool isWeekly) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = isWeekly
          ? 'weekly_trackers_${userId}_$dietType'
          : 'daily_trackers_${userId}_$dietType';
      if (isWeekly && _cachedWeeklyTrackers.isNotEmpty) {
        return List.from(_cachedWeeklyTrackers);
      } else if (!isWeekly && _cachedDailyTrackers.isNotEmpty) {
        return List.from(_cachedDailyTrackers);
      }
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final List<dynamic> decoded = jsonDecode(cached);
        final trackers =
            decoded.map((json) => TrackerGoal.fromJson(json)).toList();
        if (isWeekly) {
          _cachedWeeklyTrackers = List.from(trackers);
        } else {
          _cachedDailyTrackers = List.from(trackers);
        }
        return trackers;
      }
      return [];
    } catch (e) {
      print('Failed to get local trackers: $e');
      return [];
    }
  }

  Future<List<TrackerGoal>> getTrackers(String userId, String dietType) async {
    try {
      await _ensureMongoConnection();
      if (_useLocalFallback) {
        return await _getFallbackTrackers(userId, dietType);
      }
      final collection = await _collection;
      if (collection == null) {
        return await _getFallbackTrackers(userId, dietType);
      }
      final results = await collection.find({
        'userId': userId,
        'dietType': dietType,
      }).toList();
      final trackers = results.map((doc) => TrackerGoal.fromJson(doc)).toList();
      final dailyTrackers = trackers.where((t) => !t.isWeeklyGoal).toList();
      final weeklyTrackers = trackers.where((t) => t.isWeeklyGoal).toList();
      await _cacheTrackersLocally(
          dailyTrackers, weeklyTrackers, userId, dietType);
      return trackers;
    } catch (e) {
      print('Error fetching trackers from MongoDB: $e');
      return await _getFallbackTrackers(userId, dietType);
    }
  }

  Future<List<TrackerGoal>> _getFallbackTrackers(
      String userId, String dietType) async {
    final dailyTrackers = await _getLocalTrackers(userId, dietType, false);
    final weeklyTrackers = await _getLocalTrackers(userId, dietType, true);
    if (dailyTrackers.isEmpty && weeklyTrackers.isEmpty) {
      return _dietPlanService.getDietPlan(dietType).getGoals(userId);
    }
    return [...dailyTrackers, ...weeklyTrackers];
  }

  Future<void> initializeUserTrackers(String userId, String dietType) async {
    try {
      await _ensureMongoConnection();
      final defaultTrackers =
          _dietPlanService.getDietPlan(dietType).getGoals(userId);

      if (_useLocalFallback) {
        final dailyTrackers =
            defaultTrackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers =
            defaultTrackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
        return;
      }

      final collection = await _collection;
      if (collection == null) return;

      final existingTrackers = await collection.findOne({
        'userId': userId,
        'dietType': dietType,
      });

      if (existingTrackers == null) {
        final trackerDocs =
            defaultTrackers.map((tracker) => tracker.toJson()).toList();
        await collection.insertMany(trackerDocs);
        print('Initialized default trackers for $userId with $dietType diet.');
        final dailyTrackers =
            defaultTrackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers =
            defaultTrackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
      } else {
        print('Trackers for $userId with $dietType diet already exist.');
        await getTrackers(userId, dietType);
      }
    } catch (e) {
      print('Error initializing user trackers: $e');
      _useLocalFallback = true;
      final defaultTrackers =
          _dietPlanService.getDietPlan(dietType).getGoals(userId);
      final dailyTrackers =
          defaultTrackers.where((t) => !t.isWeeklyGoal).toList();
      final weeklyTrackers =
          defaultTrackers.where((t) => t.isWeeklyGoal).toList();
      await _cacheTrackersLocally(
          dailyTrackers, weeklyTrackers, userId, dietType);
    }
  }

  Future<List<TrackerGoal>> getDailyTrackers(
      String userId, String dietType) async {
    if (_cachedDailyTrackers.isNotEmpty) {
      return _cachedDailyTrackers;
    }
    try {
      await _ensureMongoConnection();
      if (_useLocalFallback) {
        return await _getLocalTrackers(userId, dietType, false);
      }
      final collection = await _collection;
      if (collection == null) {
        return await _getLocalTrackers(userId, dietType, false);
      }
      final results = await collection.find({
        'userId': userId,
        'dietType': dietType,
        'isWeeklyGoal': false
      }).toList();
      if (results.isEmpty) {
        print(
            'No daily trackers found for $userId ($dietType), initializing...');
        await initializeUserTrackers(userId, dietType);
        final goals = _dietPlanService.getDietPlan(dietType).getGoals(userId);
        return goals.where((g) => !g.isWeeklyGoal).toList();
      }
      final trackers = results.map((doc) => TrackerGoal.fromJson(doc)).toList();
      _cachedDailyTrackers = trackers;
      return trackers;
    } catch (e) {
      print('Error fetching daily trackers from MongoDB: $e');
      _useLocalFallback = true;
      return _getLocalTrackers(userId, dietType, false);
    }
  }

  Future<List<TrackerGoal>> getWeeklyTrackers(
      String userId, String dietType) async {
    if (_cachedWeeklyTrackers.isNotEmpty) {
      return _cachedWeeklyTrackers;
    }
    try {
      await _ensureMongoConnection();
      if (_useLocalFallback) {
        return await _getLocalTrackers(userId, dietType, true);
      }
      final collection = await _collection;
      if (collection == null) {
        return await _getLocalTrackers(userId, dietType, true);
      }
      final results = await collection.find({
        'userId': userId,
        'dietType': dietType,
        'isWeeklyGoal': true
      }).toList();
      if (results.isEmpty) {
        print(
            'No weekly trackers found for $userId ($dietType), initializing...');
        await initializeUserTrackers(userId, dietType);
        final goals = _dietPlanService.getDietPlan(dietType).getGoals(userId);
        return goals.where((g) => g.isWeeklyGoal).toList();
      }
      final trackers = results.map((doc) => TrackerGoal.fromJson(doc)).toList();
      _cachedWeeklyTrackers = trackers;
      return trackers;
    } catch (e) {
      print('Error fetching weekly trackers from MongoDB: $e');
      _useLocalFallback = true;
      return _getLocalTrackers(userId, dietType, true);
    }
  }

  Future<void> updateTrackerValue(String trackerId, double newValue) async {
    try {
      final tracker = _cachedDailyTrackers.firstWhere((t) => t.id == trackerId,
          orElse: () => _cachedWeeklyTrackers.firstWhere(
                (t) => t.id == trackerId,
              ));
      tracker.currentValue = newValue;
      tracker.lastUpdated = DateTime.now();
      _pendingUpdates.add({
        'trackerId': tracker.id,
        'updateData': {
          r'$set': {
            'currentValue': newValue,
            'lastUpdated': DateTime.now().toIso8601String()
          }
        }
      });
      // The queue will be processed, no need to await here
      _processUpdateQueue();
    } catch (e) {
      print('Failed to update tracker value for $trackerId: $e');
    }
  }

  Future<void> _processUpdateQueue() async {
    if (_isProcessingQueue || _pendingUpdates.isEmpty) {
      return;
    }
    _isProcessingQueue = true;
    final collection = await _collection;
    if (collection == null) {
      print('Cannot process update queue, no MongoDB collection.');
      _isProcessingQueue = false;
      return;
    }
    final updatesToProcess = List<Map<String, dynamic>>.from(_pendingUpdates);
    _pendingUpdates.clear();
    try {
      for (final update in updatesToProcess) {
        final trackerId = update['trackerId'];
        final updateData = update['updateData'];
        await collection.updateOne(
          mongo.where.eq('_id', trackerId),
          updateData,
        );
        print('Successfully processed update for tracker $trackerId');
      }
    } catch (e) {
      print('Error processing update queue: $e');
      _pendingUpdates.insertAll(0, updatesToProcess);
    } finally {
      _isProcessingQueue = false;
      if (_pendingUpdates.isNotEmpty) {
        _processUpdateQueue();
      }
    }
  }

  Future<void> resetTrackers(String userId, String dietType,
      {required bool isWeekly}) async {
    try {
      await _ensureMongoConnection();
      final collection = await _collection;
      if (collection == null) return;

      final trackersToReset =
          isWeekly ? _cachedWeeklyTrackers : _cachedDailyTrackers;

      // Save snapshot before resetting
      await _progressService.saveProgressSnapshot(trackersToReset,
          isWeekly ? ProgressPeriodType.weekly : ProgressPeriodType.daily);

      final query = {
        'userId': userId,
        'isWeeklyGoal': isWeekly,
      };
      await collection.updateMany(query, {
        r'$set': {
          'currentValue': 0.0,
          'lastUpdated': DateTime.now().toIso8601String()
        }
      });

      // Update local cache after db operation
      for (final tracker in trackersToReset) {
        tracker.currentValue = 0.0;
      }

      if (isWeekly) {
        await getWeeklyTrackers(userId, dietType);
      } else {
        await getDailyTrackers(userId, dietType);
      }
      print('Trackers reset for $userId (weekly: $isWeekly, diet: $dietType).');
    } catch (e) {
      print('Error resetting trackers: $e');
    }
  }

  void clearCache() {
    _cachedDailyTrackers.clear();
    _cachedWeeklyTrackers.clear();
  }
}
