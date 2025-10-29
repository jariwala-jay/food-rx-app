import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';
import '../models/tracker_goal.dart';
import '../models/tracker_progress.dart';
import 'tracker_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class TrackerService {
  final MongoDBService _mongoDBService;
  final TrackerProgressService _progressService;
  static final TrackerService _instance = TrackerService._internal();

  // Local cache of trackers
  List<TrackerGoal> _cachedDailyTrackers = [];
  List<TrackerGoal> _cachedWeeklyTrackers = [];
  bool _useLocalFallback = false;
  bool _isInitialized = false;

  // Singleton pattern
  factory TrackerService() => _instance;

  TrackerService._internal()
      : _mongoDBService = MongoDBService(),
        _progressService = TrackerProgressService();

  // Collection name for trackers in MongoDB
  static const String _collectionName = 'user_trackers';

  // Get DB collection with proper connection check
  Future<DbCollection?> get _collection async {
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

  // Robust MongoDB connection management
  Future<void> _ensureMongoConnection() async {
    try {
      if (!_isInitialized) {
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

  // Queue of pending tracker updates to MongoDB - now using a different approach
  final List<Map<String, dynamic>> _pendingUpdates = [];
  final bool _isProcessingQueue = false;
  final Completer<void>? _processingCompleter = null;

  // Cache trackers locally
  Future<void> _cacheTrackersLocally(List<TrackerGoal> daily,
      List<TrackerGoal> weekly, String userId, String dietType) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache identifiers
      final dailyCacheKey = 'daily_trackers_${userId}_$dietType';
      final weeklyCacheKey = 'weekly_trackers_${userId}_$dietType';

      // Save to shared preferences
      await prefs.setString(
          dailyCacheKey, jsonEncode(daily.map((t) => t.toJson()).toList()));
      await prefs.setString(
          weeklyCacheKey, jsonEncode(weekly.map((t) => t.toJson()).toList()));

      // Update memory cache
      _cachedDailyTrackers = List.from(daily);
      _cachedWeeklyTrackers = List.from(weekly);
    } catch (e) {
      print('Failed to cache trackers locally: $e');
    }
  }

  // Retrieve trackers from local cache
  Future<List<TrackerGoal>> _getLocalTrackers(
      String userId, String dietType, bool isWeekly) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = isWeekly
          ? 'weekly_trackers_${userId}_$dietType'
          : 'daily_trackers_${userId}_$dietType';

      // Try to get from memory cache first
      if (isWeekly && _cachedWeeklyTrackers.isNotEmpty) {
        return List.from(_cachedWeeklyTrackers);
      } else if (!isWeekly && _cachedDailyTrackers.isNotEmpty) {
        return List.from(_cachedDailyTrackers);
      }

      // Otherwise load from shared preferences
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final List<dynamic> decoded = jsonDecode(cached);
        final trackers =
            decoded.map((json) => TrackerGoal.fromJson(json)).toList();

        // Update memory cache
        if (isWeekly) {
          _cachedWeeklyTrackers = List.from(trackers);
        } else {
          _cachedDailyTrackers = List.from(trackers);
        }

        return trackers;
      }

      // If not in cache, return empty list
      return [];
    } catch (e) {
      print('Failed to get local trackers: $e');
      return [];
    }
  }

  // Fetch all trackers for a specific user and diet type
  Future<List<TrackerGoal>> getTrackers(String userId, String dietType) async {
    try {
      await _ensureMongoConnection();

      if (_useLocalFallback) {
        final dailyTrackers = await _getLocalTrackers(userId, dietType, false);
        final weeklyTrackers = await _getLocalTrackers(userId, dietType, true);
        return [...dailyTrackers, ...weeklyTrackers];
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

      // Update cache
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

  // Fallback method to get trackers from local cache
  Future<List<TrackerGoal>> _getFallbackTrackers(
      String userId, String dietType) async {
    final dailyTrackers = await _getLocalTrackers(userId, dietType, false);
    final weeklyTrackers = await _getLocalTrackers(userId, dietType, true);
    return [...dailyTrackers, ...weeklyTrackers];
  }

  // Initialize default trackers for a new user
  Future<void> initializeUserTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan}) async {
    try {
      await _ensureMongoConnection();

      // Create default trackers
      final defaultTrackers = _getDefaultTrackers(userId, dietType,
          personalizedDietPlan: personalizedDietPlan);

      if (_useLocalFallback) {
        // Save default trackers locally
        final dailyTrackers =
            defaultTrackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers =
            defaultTrackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
        return;
      }

      final collection = await _collection;
      if (collection == null) {
        await _initializeLocalTrackers(userId, dietType, defaultTrackers);
        return;
      }

      // Check if trackers already exist
      final existingTrackers =
          await collection.find({'userId': userId}).toList();
      if (existingTrackers.isNotEmpty) {
        // If trackers already exist, just cache them
        final trackers =
            existingTrackers.map((doc) => TrackerGoal.fromJson(doc)).toList();
        final dailyTrackers = trackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers = trackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
        return;
      }

      // Insert new trackers
      await _insertTrackersToMongoDB(
          collection, defaultTrackers, userId, dietType);
    } catch (e) {
      print('Error initializing trackers: $e');
      await _initializeLocalTrackers(
          userId,
          dietType,
          _getDefaultTrackers(userId, dietType,
              personalizedDietPlan: personalizedDietPlan));
    }
  }

  // Initialize trackers locally only
  Future<void> _initializeLocalTrackers(
      String userId, String dietType, List<TrackerGoal> defaultTrackers) async {
    final dailyTrackers =
        defaultTrackers.where((t) => !t.isWeeklyGoal).toList();
    final weeklyTrackers =
        defaultTrackers.where((t) => t.isWeeklyGoal).toList();
    await _cacheTrackersLocally(
        dailyTrackers, weeklyTrackers, userId, dietType);
  }

  // Update existing trackers with personalized values
  Future<void> updateTrackersWithPersonalizedPlan(String userId,
      String dietType, Map<String, dynamic> personalizedDietPlan) async {
    try {
      await _ensureMongoConnection();

      // Create new trackers with personalized values
      final personalizedTrackers = _getDefaultTrackers(userId, dietType,
          personalizedDietPlan: personalizedDietPlan);

      if (_useLocalFallback) {
        // Update local cache
        final dailyTrackers =
            personalizedTrackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers =
            personalizedTrackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
        return;
      }

      final collection = await _collection;
      if (collection == null) {
        await _initializeLocalTrackers(userId, dietType, personalizedTrackers);
        return;
      }

      // Delete existing trackers for this user
      await collection.deleteMany({'userId': userId});

      // Insert new personalized trackers
      await _insertTrackersToMongoDB(
          collection, personalizedTrackers, userId, dietType);
    } catch (e) {
      print('Error updating trackers with personalized plan: $e');
      // Fallback to local update
      final personalizedTrackers = _getDefaultTrackers(userId, dietType,
          personalizedDietPlan: personalizedDietPlan);
      await _initializeLocalTrackers(userId, dietType, personalizedTrackers);
    }
  }

  // Insert trackers to MongoDB with proper error handling
  Future<void> _insertTrackersToMongoDB(DbCollection collection,
      List<TrackerGoal> defaultTrackers, String userId, String dietType) async {
    List<TrackerGoal> createdTrackers = [];

    for (var tracker in defaultTrackers) {
      try {
        final mongoId = ObjectIdHelper.generateNew();
        final trackerWithId = tracker.copyWith(id: mongoId.toHexString());

        final json = {
          '_id': mongoId,
          'userId': userId,
          'name': tracker.name,
          'category': tracker.category.toString().split('.').last,
          'goalValue': tracker.goalValue,
          'currentValue': tracker.currentValue,
          'unit': tracker.unit.toString().split('.').last,
          'colorStart': tracker.colorStart?.value,
          'colorEnd': tracker.colorEnd?.value,
          'dietType': tracker.dietType,
          'isWeeklyGoal': tracker.isWeeklyGoal,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        await collection.insertOne(json);
        createdTrackers.add(trackerWithId);
      } catch (e) {
        print('Failed to insert tracker ${tracker.name}: $e');
      }
    }

    // Cache the successfully created trackers
    final dailyTrackers =
        createdTrackers.where((t) => !t.isWeeklyGoal).toList();
    final weeklyTrackers =
        createdTrackers.where((t) => t.isWeeklyGoal).toList();
    await _cacheTrackersLocally(
        dailyTrackers, weeklyTrackers, userId, dietType);
  }

  // Update a tracker's current value - improved approach
  Future<void> updateTrackerValue(String trackerId, double newValue) async {
    // 1. ALWAYS update the local cache first for immediate response
    await _updateTrackerInLocalCache(trackerId, newValue);

    // 2. Update MongoDB and ensure cache consistency
    try {
      await _ensureMongoConnection();
      if (!_useLocalFallback) {
        await _sendUpdateToMongoDB(trackerId, newValue);

        // 3. After successful MongoDB update, refresh the specific tracker from DB
        // to ensure cache consistency
        await _refreshTrackerFromMongoDB(trackerId);

        // 4. Trigger health goal notifications
        await _triggerHealthGoalNotifications(trackerId, newValue);
      }
    } catch (e) {
      print('MongoDB update failed, continuing with local cache: $e');
      _useLocalFallback = true;
    }
  }

  // Refresh a specific tracker from MongoDB to ensure cache consistency
  Future<void> _refreshTrackerFromMongoDB(String trackerId) async {
    try {
      final collection = await _collection;
      if (collection == null) return;

      // Parse trackerId to ObjectId using robust helper
      if (!ObjectIdHelper.isValidObjectId(trackerId)) {
        print('Invalid tracker ID format: $trackerId');
        return;
      }

      final objectId = ObjectIdHelper.parseObjectId(trackerId);
      final updatedDoc = await collection.findOne({'_id': objectId});

      if (updatedDoc != null) {
        final updatedTracker = TrackerGoal.fromJson(updatedDoc);

        // Update the specific tracker in cache
        await _updateSpecificTrackerInCache(updatedTracker);
      }
    } catch (e) {
      print('Failed to refresh tracker from MongoDB: $e');
    }
  }

  // Update a specific tracker in the cache
  Future<void> _updateSpecificTrackerInCache(TrackerGoal updatedTracker) async {
    try {
      bool updated = false;

      // Update in daily trackers
      for (int i = 0; i < _cachedDailyTrackers.length; i++) {
        if (_cachedDailyTrackers[i].id == updatedTracker.id) {
          _cachedDailyTrackers[i] = updatedTracker;
          updated = true;
          break;
        }
      }

      // Update in weekly trackers if not found in daily
      if (!updated) {
        for (int i = 0; i < _cachedWeeklyTrackers.length; i++) {
          if (_cachedWeeklyTrackers[i].id == updatedTracker.id) {
            _cachedWeeklyTrackers[i] = updatedTracker;
            updated = true;
            break;
          }
        }
      }

      if (updated) {
        await _persistCachedTrackers();
      }
    } catch (e) {
      print('Failed to update specific tracker in cache: $e');
    }
  }

  // Update tracker in local cache with better error handling
  Future<void> _updateTrackerInLocalCache(
      String trackerId, double newValue) async {
    try {
      String cleanId = trackerId;
      if (trackerId.startsWith('ObjectId("') && trackerId.endsWith('")')) {
        cleanId = trackerId.substring(9, trackerId.length - 2);
      }

      bool updated = false;

      // Create new lists to avoid concurrent modification
      List<TrackerGoal> updatedDailyTrackers = [];
      for (final tracker in _cachedDailyTrackers) {
        if (tracker.id == trackerId || tracker.id == cleanId) {
          updatedDailyTrackers.add(tracker.copyWith(
            currentValue: newValue,
            lastUpdated: DateTime.now(),
          ));
          updated = true;
        } else {
          updatedDailyTrackers.add(tracker);
        }
      }

      List<TrackerGoal> updatedWeeklyTrackers = [];
      if (!updated) {
        for (final tracker in _cachedWeeklyTrackers) {
          if (tracker.id == trackerId || tracker.id == cleanId) {
            updatedWeeklyTrackers.add(tracker.copyWith(
              currentValue: newValue,
              lastUpdated: DateTime.now(),
            ));
            updated = true;
          } else {
            updatedWeeklyTrackers.add(tracker);
          }
        }
      } else {
        updatedWeeklyTrackers = List.from(_cachedWeeklyTrackers);
      }

      if (updated) {
        _cachedDailyTrackers = updatedDailyTrackers;
        _cachedWeeklyTrackers = updatedWeeklyTrackers;
        await _persistCachedTrackers();
      }
    } catch (e) {
      print('Failed to update local cache: $e');
    }
  }

  // Persist cached trackers to shared preferences
  Future<void> _persistCachedTrackers() async {
    try {
      if (_cachedDailyTrackers.isEmpty && _cachedWeeklyTrackers.isEmpty) {
        return;
      }

      final userId = _cachedDailyTrackers.isNotEmpty
          ? _cachedDailyTrackers.first.userId
          : _cachedWeeklyTrackers.first.userId;

      final dietType = _cachedDailyTrackers.isNotEmpty
          ? _cachedDailyTrackers.first.dietType
          : _cachedWeeklyTrackers.first.dietType;

      await _cacheTrackersLocally(
          _cachedDailyTrackers, _cachedWeeklyTrackers, userId, dietType);
    } catch (e) {
      print('Failed to persist cached trackers: $e');
    }
  }

  // Get all weekly trackers
  Future<List<TrackerGoal>> getWeeklyTrackers(
      String userId, String dietType) async {
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

      final trackers = results.map((doc) => TrackerGoal.fromJson(doc)).toList();

      // Update cache
      _cachedWeeklyTrackers = List.from(trackers);
      await _persistCachedTrackers();

      return trackers;
    } catch (e) {
      print('Error fetching weekly trackers: $e');
      return await _getLocalTrackers(userId, dietType, true);
    }
  }

  // Get all daily trackers
  Future<List<TrackerGoal>> getDailyTrackers(
      String userId, String dietType) async {
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

      final trackers = results.map((doc) => TrackerGoal.fromJson(doc)).toList();

      // Update cache
      _cachedDailyTrackers = List.from(trackers);
      await _persistCachedTrackers();

      return trackers;
    } catch (e) {
      print('Error fetching daily trackers: $e');
      return await _getLocalTrackers(userId, dietType, false);
    }
  }

  // Reset daily trackers (e.g., at midnight)
  Future<void> resetDailyTrackers(String userId) async {
    try {
      // Get current daily trackers before resetting
      final currentTrackers = await getDailyTrackers(
          userId,
          _cachedDailyTrackers.isNotEmpty
              ? _cachedDailyTrackers.first.dietType
              : 'MyPlate');

      // Save progress snapshot for analytics (only if there's progress to save)
      if (currentTrackers.any((t) => t.currentValue > 0)) {
        await _progressService.saveProgressSnapshot(
            currentTrackers, ProgressPeriodType.daily);
      }

      // First reset in local cache
      await _resetTrackersInLocalCache(userId, false);

      // Try to reset in MongoDB if available
      await _ensureMongoConnection();
      if (!_useLocalFallback) {
        final collection = await _collection;
        if (collection != null) {
          try {
            await collection.updateMany(
              {'userId': userId, 'isWeeklyGoal': false},
              {
                '\$set': {
                  'currentValue': 0.0,
                  'lastUpdated': DateTime.now().toIso8601String()
                }
              },
            );
          } catch (e) {
            print('Failed to reset daily trackers in MongoDB: $e');
          }
        }
      }
    } catch (e) {
      print('Error resetting daily trackers: $e');
    }
  }

  // Reset weekly trackers (e.g., on Sunday midnight)
  Future<void> resetWeeklyTrackers(String userId) async {
    try {
      // Get current weekly trackers before resetting
      final currentTrackers = await getWeeklyTrackers(
          userId,
          _cachedWeeklyTrackers.isNotEmpty
              ? _cachedWeeklyTrackers.first.dietType
              : 'MyPlate');

      // Save progress snapshot for analytics (only if there's progress to save)
      if (currentTrackers.any((t) => t.currentValue > 0)) {
        await _progressService.saveProgressSnapshot(
            currentTrackers, ProgressPeriodType.weekly);
      }

      // First reset in local cache
      await _resetTrackersInLocalCache(userId, true);

      // Try to reset in MongoDB if available
      await _ensureMongoConnection();
      if (!_useLocalFallback) {
        final collection = await _collection;
        if (collection != null) {
          try {
            await collection.updateMany(
              {'userId': userId, 'isWeeklyGoal': true},
              {
                '\$set': {
                  'currentValue': 0.0,
                  'lastUpdated': DateTime.now().toIso8601String()
                }
              },
            );
          } catch (e) {
            print('Failed to reset weekly trackers in MongoDB: $e');
          }
        }
      }
    } catch (e) {
      print('Error resetting weekly trackers: $e');
    }
  }

  // Reset trackers in local cache
  Future<void> _resetTrackersInLocalCache(String userId, bool isWeekly) async {
    try {
      if (isWeekly) {
        List<TrackerGoal> resetTrackers = [];
        for (final tracker in _cachedWeeklyTrackers) {
          resetTrackers.add(tracker.copyWith(
            currentValue: 0.0,
            lastUpdated: DateTime.now(),
          ));
        }
        _cachedWeeklyTrackers = resetTrackers;
      } else {
        List<TrackerGoal> resetTrackers = [];
        for (final tracker in _cachedDailyTrackers) {
          resetTrackers.add(tracker.copyWith(
            currentValue: 0.0,
            lastUpdated: DateTime.now(),
          ));
        }
        _cachedDailyTrackers = resetTrackers;
      }

      await _persistCachedTrackers();
    } catch (e) {
      print('Failed to reset trackers in local cache: $e');
    }
  }

  // Cleanup duplicate trackers (MongoDB only)
  Future<void> cleanupDuplicateTrackers(String userId) async {
    try {
      await _ensureMongoConnection();
      if (_useLocalFallback) return;

      final collection = await _collection;
      if (collection == null) return;

      // Find all trackers for the user
      final trackers = await collection.find({'userId': userId}).toList();

      // Group by name and isWeeklyGoal to find duplicates
      Map<String, List<Map<String, dynamic>>> groups = {};

      for (final tracker in trackers) {
        final key = '${tracker['name']}_${tracker['isWeeklyGoal']}';
        groups[key] ??= [];
        groups[key]!.add(tracker);
      }

      // Remove duplicates (keep the most recent one)
      for (final group in groups.values) {
        if (group.length > 1) {
          // Sort by lastUpdated descending
          group.sort((a, b) {
            final dateA =
                DateTime.tryParse(a['lastUpdated'] ?? '') ?? DateTime(1970);
            final dateB =
                DateTime.tryParse(b['lastUpdated'] ?? '') ?? DateTime(1970);
            return dateB.compareTo(dateA);
          });

          // Remove all except the first (most recent)
          for (int i = 1; i < group.length; i++) {
            try {
              await collection.deleteOne({'_id': group[i]['_id']});
              print('Removed duplicate tracker: ${group[i]['name']}');
            } catch (e) {
              print('Failed to remove duplicate tracker: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up duplicate trackers: $e');
    }
  }

  // Helper method to get default trackers based on diet type
  List<TrackerGoal> _getDefaultTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan}) {
    if (dietType == 'DASH') {
      return _getDefaultDashTrackers(userId,
          personalizedDietPlan: personalizedDietPlan);
    } else {
      return _getDefaultMyPlateTrackers(userId,
          personalizedDietPlan: personalizedDietPlan);
    }
  }

  // Default trackers for DASH diet
  List<TrackerGoal> _getDefaultDashTrackers(String userId,
      {Map<String, dynamic>? personalizedDietPlan}) {
    // Use personalized values if available, otherwise fall back to defaults
    final grains = personalizedDietPlan?['grainsMax']?.toDouble() ?? 6.0;
    final vegetables =
        personalizedDietPlan?['vegetablesMax']?.toDouble() ?? 4.0;
    final fruits = personalizedDietPlan?['fruitsMax']?.toDouble() ?? 4.0;
    final dairy = personalizedDietPlan?['dairyMax']?.toDouble() ?? 2.0;
    final leanMeats = personalizedDietPlan?['leanMeatsMax']?.toDouble() ?? 6.0;
    final oils = personalizedDietPlan?['oilsMax']?.toDouble() ?? 2.0;
    final nutsLegumes =
        personalizedDietPlan?['nutsLegumesPerWeek']?.toDouble() ?? 4.0;
    final sweets = personalizedDietPlan?['sweetsMaxPerWeek']?.toDouble() ?? 5.0;

    // Check if there are daily limits for sweets (2600+ kcal plans)
    final sweetsMaxPerDay =
        personalizedDietPlan?['sweetsMaxPerDay']?.toDouble();
    final hasDailySweets = sweetsMaxPerDay != null && sweetsMaxPerDay > 0;
    final sodium = personalizedDietPlan?['sodium']?.toDouble() ?? 1500.0;

    return [
      TrackerGoal(
        userId: userId,
        name: 'Veggies',
        category: TrackerCategory.veggies,
        goalValue: vegetables,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: 'DASH',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Fruits',
        category: TrackerCategory.fruits,
        goalValue: fruits,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: 'DASH',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Protein',
        category: TrackerCategory.leanMeat,
        goalValue: leanMeats,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: 'DASH',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Grains',
        category: TrackerCategory.grains,
        goalValue: grains,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: 'DASH',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Dairy',
        category: TrackerCategory.dairy,
        goalValue: dairy,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: 'DASH',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Fats/oils',
        category: TrackerCategory.fatsOils,
        goalValue: oils,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: 'DASH',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Water',
        category: TrackerCategory.water,
        goalValue: 3.0,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFF2196F3),
        colorEnd: const Color(0xFF90CAF9),
        dietType: 'DASH',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Sweets',
        category: TrackerCategory.sweets,
        goalValue: hasDailySweets ? sweetsMaxPerDay! : sweets,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: 'DASH',
        isWeeklyGoal: !hasDailySweets,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Nuts',
        category: TrackerCategory.nutsLegumes,
        goalValue: nutsLegumes,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: 'DASH',
        isWeeklyGoal: true,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Sodium',
        category: TrackerCategory.sodium,
        goalValue: sodium,
        unit: TrackerUnit.mg,
        colorStart: const Color(0xFFB0BEC5), // Blue Grey
        colorEnd: const Color(0xFF78909C),
        dietType: 'DASH',
        isWeeklyGoal: false,
      ),
    ];
  }

  // Default trackers for MyPlate diet
  List<TrackerGoal> _getDefaultMyPlateTrackers(String userId,
      {Map<String, dynamic>? personalizedDietPlan}) {
    // Use personalized values if available, otherwise fall back to defaults
    final fruits = personalizedDietPlan?['fruits']?.toDouble() ?? 2.0;
    final vegetables = personalizedDietPlan?['vegetables']?.toDouble() ?? 2.5;
    final grains = personalizedDietPlan?['grains']?.toDouble() ?? 6.0;
    final protein = personalizedDietPlan?['protein']?.toDouble() ?? 5.5;
    final dairy = personalizedDietPlan?['dairy']?.toDouble() ?? 3.0;
    final addedSugars =
        personalizedDietPlan?['addedSugarsMax']?.toDouble() ?? 50.0;
    final saturatedFat =
        personalizedDietPlan?['saturatedFatMax']?.toDouble() ?? 22.0;
    final sodium = personalizedDietPlan?['sodiumMax']?.toDouble() ?? 2300.0;

    return [
      TrackerGoal(
        userId: userId,
        name: 'Veggies',
        category: TrackerCategory.veggies,
        goalValue: vegetables,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: 'MyPlate',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Fruits',
        category: TrackerCategory.fruits,
        goalValue: fruits,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: 'MyPlate',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Protein',
        category: TrackerCategory.protein,
        goalValue: protein,
        unit: TrackerUnit.oz,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: 'MyPlate',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Grains',
        category: TrackerCategory.grains,
        goalValue: grains,
        unit: TrackerUnit.oz,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: 'MyPlate',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Dairy',
        category: TrackerCategory.dairy,
        goalValue: dairy,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: 'MyPlate',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Water',
        category: TrackerCategory.water,
        goalValue: 8.0,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFF2196F3),
        colorEnd: const Color(0xFF90CAF9),
        dietType: 'MyPlate',
      ),
      TrackerGoal(
        userId: userId,
        name: 'Sodium',
        category: TrackerCategory.sodium,
        goalValue: sodium,
        unit: TrackerUnit.mg,
        colorStart: const Color(0xFFB0BEC5),
        colorEnd: const Color(0xFF78909C),
        dietType: 'MyPlate',
      ),
    ];
  }

  // Core MongoDB update logic with better error handling
  Future<void> _sendUpdateToMongoDB(String trackerId, double newValue) async {
    if (_useLocalFallback) return;

    try {
      final collection = await _collection;
      if (collection == null) return;

      // Parse trackerId to ObjectId using robust helper
      if (!ObjectIdHelper.isValidObjectId(trackerId)) {
        throw Exception('Invalid ObjectId format: $trackerId');
      }

      final objectId = ObjectIdHelper.parseObjectId(trackerId);

      // Perform the update
      final result = await collection.updateOne(
        {'_id': objectId},
        {
          '\$set': {
            'currentValue': newValue,
            'lastUpdated': DateTime.now().toIso8601String(),
          }
        },
      );

      if (!result.isSuccess) {
        throw Exception('Update failed: ${result.writeError?.errmsg}');
      }
    } catch (e) {
      print('MongoDB update failed for tracker $trackerId: $e');
      _useLocalFallback = true;
      rethrow;
    }
  }

  // Trigger health goal notifications when tracker values are updated
  Future<void> _triggerHealthGoalNotifications(
      String trackerId, double newValue) async {
    try {
      // Health goal notifications removed - simplified notification system
    } catch (e) {
      print('Error triggering health goal notifications: $e');
    }
  }
}
