import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/tip.dart';
import '../services/tip_service.dart';

class TipProvider with ChangeNotifier {
  final TipService _tipService;
  List<Tip> _shownTips = [];
  DateTime _lastUpdate = DateTime.now();
  bool _isLoading = false;
  final Random _random = Random();
  String? _lastUserId;
  List<String>? _lastMedicalConditions;

  TipProvider(this._tipService);

  bool get isLoading => _isLoading;
  List<Tip> get shownTips => _shownTips;

  Future<void> initializeTips(
      List<String> medicalConditions, String userId) async {
    print(
        'Initializing tips for user: $userId with conditions: $medicalConditions');

    // Check if we need to update tips:
    // 1. If no tips are shown
    // 2. If it's been more than a day since last update
    // 3. If the user has changed
    // 4. If the medical conditions have changed
    final shouldUpdate = _shownTips.isEmpty ||
        DateTime.now().difference(_lastUpdate).inDays >= 1 ||
        _lastUserId != userId ||
        !_areMedicalConditionsEqual(_lastMedicalConditions, medicalConditions);

    if (shouldUpdate) {
      print('Updating shown tips...');
      print(
          'Reason: ${_getUpdateReason(_shownTips.isEmpty, _lastUserId != userId, !_areMedicalConditionsEqual(_lastMedicalConditions, medicalConditions))}');
      await _updateShownTips(medicalConditions, userId);
      _lastUserId = userId;
      _lastMedicalConditions = List<String>.from(medicalConditions);
    } else {
      print('Using cached tips');
    }
  }

  String _getUpdateReason(
      bool noTips, bool userChanged, bool conditionsChanged) {
    final reasons = <String>[];
    if (noTips) reasons.add('no tips shown');
    if (userChanged) reasons.add('user changed');
    if (conditionsChanged) reasons.add('medical conditions changed');
    if (DateTime.now().difference(_lastUpdate).inDays >= 1)
      reasons.add('tips expired');
    return reasons.join(', ');
  }

  bool _areMedicalConditionsEqual(List<String>? a, List<String> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    return Set<String>.from(a).difference(Set<String>.from(b)).isEmpty;
  }

  Future<void> _updateShownTips(
      List<String> medicalConditions, String userId) async {
    if (_isLoading) return;

    _isLoading = true;
    _notifyListeners();

    try {
      print('Fetching all tips from service...');
      final List<Tip> allTips = await _tipService.getAllTips();
      print('Retrieved ${allTips.length} tips from service');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Filter out tips shown to the user today
      final availableTips = allTips.where((tip) {
        final lastShown = tip.getLastShownForUser(userId);
        return lastShown == null ||
            DateTime(lastShown.year, lastShown.month, lastShown.day) != today;
      }).toList();

      print('${availableTips.length} tips available for today');

      // Separate tips by category
      final conditionTips = availableTips
          .where((tip) => medicalConditions.contains(tip.category))
          .toList();

      final generalTips =
          availableTips.where((tip) => tip.category == 'General').toList();

      print(
          'Found ${conditionTips.length} condition-specific tips and ${generalTips.length} general tips');

      // Select 2 condition-specific tips and 2 general tips
      final selectedTips = <Tip>[];

      // Select 2 condition-specific tips
      if (conditionTips.isNotEmpty) {
        final shuffledConditionTips = List<Tip>.from(conditionTips)
          ..shuffle(_random);
        final conditionTipsToAdd = shuffledConditionTips.take(2).toList();
        selectedTips.addAll(conditionTipsToAdd);
        print(
            'Selected condition-specific tips: ${conditionTipsToAdd.map((t) => t.title).join(', ')}');
      }

      // Select 2 general tips
      if (generalTips.isNotEmpty) {
        final shuffledGeneralTips = List<Tip>.from(generalTips)
          ..shuffle(_random);
        final generalTipsToAdd = shuffledGeneralTips.take(2).toList();
        selectedTips.addAll(generalTipsToAdd);
        print(
            'Selected general tips: ${generalTipsToAdd.map((t) => t.title).join(', ')}');
      }

      // If we don't have enough tips, fill with any available tips
      while (selectedTips.length < 4 && availableTips.isNotEmpty) {
        final remainingTips =
            availableTips.where((tip) => !selectedTips.contains(tip)).toList();

        if (remainingTips.isEmpty) break;

        final randomIndex = _random.nextInt(remainingTips.length);
        selectedTips.add(remainingTips[randomIndex]);
        print('Added additional tip: ${remainingTips[randomIndex].title}');
      }

      // Update last shown date and view count for selected tips
      for (var tip in selectedTips) {
        final updatedTip = tip.copyWith(
          lastShownToUsers: {
            ...tip.lastShownToUsers,
            userId: now,
          },
          viewCountByUser: {
            ...tip.viewCountByUser,
            userId: (tip.getViewCountForUser(userId) + 1),
          },
        );
        await _tipService.updateTip(updatedTip);
      }

      _shownTips = selectedTips;
      _lastUpdate = now;
      print(
          'Final selected tips: ${selectedTips.map((t) => t.title).join(', ')}');
    } catch (e) {
      print('Error updating shown tips: $e');
    } finally {
      _isLoading = false;
      _notifyListeners();
    }
  }

  Future<void> markTipAsViewed(String tipId, String userId) async {
    try {
      final index = _shownTips.indexWhere((tip) => tip.id == tipId);
      if (index != -1) {
        final tip = _shownTips[index];
        final updatedTip = tip.copyWith(
          viewCountByUser: {
            ...tip.viewCountByUser,
            userId: (tip.getViewCountForUser(userId) + 1),
          },
        );
        await _tipService.updateTip(updatedTip);
        _shownTips[index] = updatedTip;
        _notifyListeners();
      }
    } catch (e) {
      print('Error marking tip as viewed: $e');
    }
  }

  void _notifyListeners() {
    if (!_isLoading) {
      notifyListeners();
    }
  }
}
