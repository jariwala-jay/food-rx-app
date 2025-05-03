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
    final shouldUpdate = _shownTips.isEmpty ||
        DateTime.now().difference(_lastUpdate).inDays >= 1 ||
        _lastUserId != userId ||
        !_areMedicalConditionsEqual(_lastMedicalConditions, medicalConditions);

    if (shouldUpdate) {
      await _updateShownTips(medicalConditions, userId);
      _lastUserId = userId;
      _lastMedicalConditions = List<String>.from(medicalConditions);
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
      final List<Tip> allTips = await _tipService.getAllTips();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Filter out tips shown to the user today
      final availableTips = allTips.where((tip) {
        final lastShown = tip.getLastShownForUser(userId);
        return lastShown == null ||
            DateTime(lastShown.year, lastShown.month, lastShown.day) != today;
      }).toList();

      // Separate tips by category
      final conditionTips = availableTips
          .where((tip) => medicalConditions.contains(tip.category))
          .toList();

      final generalTips =
          availableTips.where((tip) => tip.category == 'General').toList();

      // Select 2 condition-specific tips and 2 general tips
      final selectedTips = <Tip>[];

      // Select 2 condition-specific tips
      if (conditionTips.isNotEmpty) {
        final shuffledConditionTips = List<Tip>.from(conditionTips)
          ..shuffle(_random);
        final conditionTipsToAdd = shuffledConditionTips.take(2).toList();
        selectedTips.addAll(conditionTipsToAdd);
      }

      // Select 2 general tips
      if (generalTips.isNotEmpty) {
        final shuffledGeneralTips = List<Tip>.from(generalTips)
          ..shuffle(_random);
        final generalTipsToAdd = shuffledGeneralTips.take(2).toList();
        selectedTips.addAll(generalTipsToAdd);
      }

      // If we don't have enough tips, fill with any available tips
      while (selectedTips.length < 4 && availableTips.isNotEmpty) {
        final remainingTips =
            availableTips.where((tip) => !selectedTips.contains(tip)).toList();

        if (remainingTips.isEmpty) break;

        final randomIndex = _random.nextInt(remainingTips.length);
        selectedTips.add(remainingTips[randomIndex]);
      }

      // Update last shown date and view count for selected tips
      for (var tip in selectedTips) {
        try {
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
        } catch (e) {
          print('Failed to update tip ${tip.id}: $e');
          // Continue with other tips even if one fails
        }
      }

      _shownTips = selectedTips;
      _lastUpdate = now;
    } catch (e) {
      print('Error updating shown tips: $e');
      // Keep existing tips if update fails
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
      print('Failed to mark tip as viewed: $e');
      // Don't throw the error to prevent UI disruption
    }
  }

  void _notifyListeners() {
    if (!_isLoading) {
      notifyListeners();
    }
  }
}
