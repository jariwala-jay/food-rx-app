import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/models/tracker_progress.dart';
import 'package:flutter_app/features/tracking/services/tracker_api_service.dart';
import 'package:flutter_app/features/tracking/widgets/tracker_card.dart';

/// Fitbit-style history view: calendar date + bar list of meal goals with
/// same color logic (orange / yellow / green / red) per logged value.
/// Only shows data through yesterday (today is excluded); past dates use
/// saved progress snapshots.
class MealGoalsHistoryPage extends StatefulWidget {
  final String userId;
  final String? dietType;
  /// Optional. When set, the date picker's first selectable date is this day (e.g. account creation).
  final DateTime? accountCreatedAt;

  const MealGoalsHistoryPage({
    super.key,
    required this.userId,
    this.dietType,
    this.accountCreatedAt,
  });

  @override
  State<MealGoalsHistoryPage> createState() => _MealGoalsHistoryPageState();
}

class _MealGoalsHistoryPageState extends State<MealGoalsHistoryPage> {
  final TrackerApiService _api = TrackerApiService();
  /// Default to yesterday; Goal Progress shows data only through yesterday (today excluded).
  late DateTime _selectedDate;
  List<TrackerProgress> _progressList = [];
  List<TrackerGoal>? _todayTrackers;
  /// When there is no data for the selected date, this holds the most recent
  /// earlier date that has any logged progress (if found).
  DateTime? _lastLoggedDateForSelected;
  // Weekly veggies history data for the selected week (0 = no data)
  List<double> _veggiesWeekServings = List.filled(7, 0.0);
  double? _veggiesGoalValue;
  OverlayEntry? _veggiesHoverOverlay;
  // Weekly fruits history data for the selected week (0 = no data)
  List<double> _fruitsWeekServings = List.filled(7, 0.0);
  double? _fruitsGoalValue;
  OverlayEntry? _fruitsHoverOverlay;
  // Weekly water history data for the selected week (0 = no data)
  List<double> _waterWeekServings = List.filled(7, 0.0);
  double? _waterGoalValue;
  OverlayEntry? _waterHoverOverlay;
  // Weekly protein history data for the selected week (0 = no data)
  List<double> _proteinWeekServings = List.filled(7, 0.0);
  double? _proteinGoalValue;
  OverlayEntry? _proteinHoverOverlay;
  List<double> _grainsWeekServings = List.filled(7, 0.0);
  double? _grainsGoalValue;
  OverlayEntry? _grainsHoverOverlay;
  List<double> _dairyWeekServings = List.filled(7, 0.0);
  double? _dairyGoalValue;
  OverlayEntry? _dairyHoverOverlay;
  List<double> _fatsOilsWeekServings = List.filled(7, 0.0);
  double? _fatsOilsGoalValue;
  OverlayEntry? _fatsOilsHoverOverlay;
  List<double> _sodiumWeekServings = List.filled(7, 0.0);
  double? _sodiumGoalValue;
  OverlayEntry? _sodiumHoverOverlay;
  bool _loading = true;
  String? _error;
  late PageController _weeklyGraphPageController;
  int _weeklyGraphPageIndex = 0;
  bool _showCarouselArrows = false;
  Timer? _carouselArrowsHideTimer;
  /// DASH and DiabetesPlate include Fats/Oils; MyPlate has 7 without Fats/Oils.
  List<String> get _effectiveCategoryOrder {
    final diet = (widget.dietType ?? '').toString();
    if (diet == 'DASH' || diet == 'DiabetesPlate') {
      return const [
        'veggies', 'fruits', 'protein', 'grains', 'dairy',
        'fatsOils', 'water', 'sodium',
      ];
    }
    return const [
      'veggies', 'fruits', 'protein', 'grains', 'dairy',
      'water', 'sodium',
    ];
  }


  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .subtract(const Duration(days: 1));
    _weeklyGraphPageController = PageController();
    _weeklyGraphPageController.addListener(_onWeeklyGraphPageChanged);
    _loadProgressForDate();
  }

  int get _weeklyGraphCount => _effectiveCategoryOrder.length;

  void _onWeeklyGraphPageChanged() {
    if (!_weeklyGraphPageController.hasClients) return;
    final page = _weeklyGraphPageController.page?.round() ?? 0;
    if (page != _weeklyGraphPageIndex && mounted) {
      setState(() => _weeklyGraphPageIndex = page.clamp(0, _weeklyGraphCount - 1));
    }
  }

  @override
  void dispose() {
    _carouselArrowsHideTimer?.cancel();
    _weeklyGraphPageController.removeListener(_onWeeklyGraphPageChanged);
    _weeklyGraphPageController.dispose();
    super.dispose();
  }

  void _showCarouselArrowsTemporarily() {
    _carouselArrowsHideTimer?.cancel();
    if (!_showCarouselArrows && mounted) setState(() => _showCarouselArrows = true);
    _carouselArrowsHideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showCarouselArrows = false);
    });
  }

  TrackerCategory _categoryFromString(String s) {
    final str = s.contains('.') ? s.split('.').last : s;
    return TrackerCategory.values.firstWhere(
      (e) => e.toString().split('.').last == str,
      orElse: () => TrackerCategory.other,
    );
  }

  String _formatUnit(String unit) {
    if (unit.isEmpty) return '';
    switch (unit.toLowerCase()) {
      case 'cups':
        return 'Cups';
      case 'oz':
        return 'oz';
      case 'mg':
        return 'mg';
      case 'servings':
        return 'Servings';
      default:
        return unit;
    }
  }

  String _dateLabel(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }

  bool get _isSelectedToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadProgressForDate() async {
    setState(() {
      _loading = true;
      _error = null;
      _todayTrackers = null;
      _lastLoggedDateForSelected = null;
    });
    try {
      if (_isSelectedToday) {
        final trackers = await _api.getTrackers(
          widget.userId,
          dietType: widget.dietType,
          isWeeklyGoal: false,
        );
        if (mounted) {
          setState(() {
            _todayTrackers = trackers;
            _progressList = [];
            _loading = false;
          });
          _loadWeekBarChartData();
        }
      } else {
        final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        final list = await _api.getProgress(
          periodType: 'daily',
          startDate: start.toUtc().toIso8601String(),
          endDate: end.toUtc().toIso8601String(),
        );
        DateTime? lastLoggedDate;
        if (list.isEmpty) {
          // Find the most recent earlier date (before the selected date) that has any progress.
          final historyStart = widget.accountCreatedAt != null
              ? DateTime(widget.accountCreatedAt!.year, widget.accountCreatedAt!.month, widget.accountCreatedAt!.day)
              : DateTime(2020);
          final history = await _api.getProgress(
            periodType: 'daily',
            startDate: historyStart.toUtc().toIso8601String(),
            endDate: start.toUtc().toIso8601String(),
          );
          for (final p in history) {
            final d = DateTime(p.progressDate.year, p.progressDate.month, p.progressDate.day);
            if (d.isBefore(start)) {
              if (lastLoggedDate == null || d.isAfter(lastLoggedDate)) {
                lastLoggedDate = d;
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _progressList = list;
            _todayTrackers = null;
            _loading = false;
            _lastLoggedDateForSelected = lastLoggedDate;
          });
          _loadWeekBarChartData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _progressList = [];
          _todayTrackers = null;
        });
      }
    }
  }

  /// Load 7 days of completion data for the bar chart (Fitbit-style).
  Future<void> _loadWeekBarChartData() async {
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));
    try {
      final list = await _api.getProgress(
        periodType: 'daily',
        startDate: start.toUtc().toIso8601String(),
        endDate: end.add(const Duration(days: 1)).toUtc().toIso8601String(),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Build map of latest veggies and fruits progress per day in the selected week
      final veggiesByDay = <DateTime, TrackerProgress>{};
      final fruitsByDay = <DateTime, TrackerProgress>{};
      final waterByDay = <DateTime, TrackerProgress>{};
      final proteinByDay = <DateTime, TrackerProgress>{};
      final grainsByDay = <DateTime, TrackerProgress>{};
      final dairyByDay = <DateTime, TrackerProgress>{};
      final fatsOilsByDay = <DateTime, TrackerProgress>{};
      final sodiumByDay = <DateTime, TrackerProgress>{};
      for (final p in list) {
        final d = DateTime(p.progressDate.year, p.progressDate.month, p.progressDate.day);
        final key = p.trackerCategory.contains('.')
            ? p.trackerCategory.split('.').last
            : p.trackerCategory;
        if (key == 'veggies') {
          final existing = veggiesByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            veggiesByDay[d] = p;
          }
        } else if (key == 'fruits') {
          final existing = fruitsByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            fruitsByDay[d] = p;
          }
        } else if (key == 'water') {
          final existing = waterByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            waterByDay[d] = p;
          }
        } else if (key == 'protein' || key == 'leanMeat') {
          final existing = proteinByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            proteinByDay[d] = p;
          }
        } else if (key == 'grains') {
          final existing = grainsByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            grainsByDay[d] = p;
          }
        } else if (key == 'dairy') {
          final existing = dairyByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            dairyByDay[d] = p;
          }
        } else if (key == 'fatsOils') {
          final existing = fatsOilsByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            fatsOilsByDay[d] = p;
          }
        } else if (key == 'sodium') {
          final existing = sodiumByDay[d];
          if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
            sodiumByDay[d] = p;
          }
        }
      }
      final weekServings = <double>[];
      double? goalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('veggies');
          if (tracker != null) {
            weekServings.add(tracker.currentValue);
            goalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            weekServings.add(0.0); // no data = 0
          }
        } else {
          final p = veggiesByDay[d];
          if (p != null) {
            weekServings.add(p.achievedValue);
            if (goalValue == null && p.targetValue > 0) {
              goalValue = p.targetValue;
            }
          } else {
            weekServings.add(0.0); // no data = 0
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEnd = veggiesByDay[end];
      if (pEnd != null && pEnd.targetValue > 0) {
        goalValue = pEnd.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = veggiesByDay[d];
          if (p != null && p.targetValue > 0) {
            goalValue = p.targetValue;
            break;
          }
        }
      }
      // Fallback goal value from today's trackers if not found in history
      if (goalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('veggies');
        if (tracker != null && tracker.goalValue > 0) {
          goalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _veggiesWeekServings = weekServings;
          _veggiesGoalValue = goalValue;
        });
      }

      // Load fruits weekly data
      final fruitsWeekServings = <double>[];
      double? fruitsGoalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('fruits');
          if (tracker != null) {
            fruitsWeekServings.add(tracker.currentValue);
            fruitsGoalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            fruitsWeekServings.add(0.0);
          }
        } else {
          final p = fruitsByDay[d];
          if (p != null) {
            fruitsWeekServings.add(p.achievedValue);
            if (fruitsGoalValue == null && p.targetValue > 0) {
              fruitsGoalValue = p.targetValue;
            }
          } else {
            fruitsWeekServings.add(0.0);
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEndFruits = fruitsByDay[end];
      if (pEndFruits != null && pEndFruits.targetValue > 0) {
        fruitsGoalValue = pEndFruits.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = fruitsByDay[d];
          if (p != null && p.targetValue > 0) {
            fruitsGoalValue = p.targetValue;
            break;
          }
        }
      }
      if (fruitsGoalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('fruits');
        if (tracker != null && tracker.goalValue > 0) {
          fruitsGoalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _fruitsWeekServings = fruitsWeekServings;
          _fruitsGoalValue = fruitsGoalValue;
        });
      }

      // Load water weekly data
      final waterWeekServings = <double>[];
      double? waterGoalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('water');
          if (tracker != null) {
            waterWeekServings.add(tracker.currentValue);
            waterGoalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            waterWeekServings.add(0.0);
          }
        } else {
          final p = waterByDay[d];
          if (p != null) {
            waterWeekServings.add(p.achievedValue);
            if (waterGoalValue == null && p.targetValue > 0) {
              waterGoalValue = p.targetValue;
            }
          } else {
            waterWeekServings.add(0.0);
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEndWater = waterByDay[end];
      if (pEndWater != null && pEndWater.targetValue > 0) {
        waterGoalValue = pEndWater.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = waterByDay[d];
          if (p != null && p.targetValue > 0) {
            waterGoalValue = p.targetValue;
            break;
          }
        }
      }
      if (waterGoalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('water');
        if (tracker != null && tracker.goalValue > 0) {
          waterGoalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _waterWeekServings = waterWeekServings;
          _waterGoalValue = waterGoalValue;
        });
      }

      // Load protein weekly data
      final proteinWeekServings = <double>[];
      double? proteinGoalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('protein');
          if (tracker != null) {
            proteinWeekServings.add(tracker.currentValue);
            proteinGoalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            proteinWeekServings.add(0.0);
          }
        } else {
          final p = proteinByDay[d];
          if (p != null) {
            proteinWeekServings.add(p.achievedValue);
            if (proteinGoalValue == null && p.targetValue > 0) {
              proteinGoalValue = p.targetValue;
            }
          } else {
            proteinWeekServings.add(0.0);
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEndProtein = proteinByDay[end];
      if (pEndProtein != null && pEndProtein.targetValue > 0) {
        proteinGoalValue = pEndProtein.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = proteinByDay[d];
          if (p != null && p.targetValue > 0) {
            proteinGoalValue = p.targetValue;
            break;
          }
        }
      }
      if (proteinGoalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('protein');
        if (tracker != null && tracker.goalValue > 0) {
          proteinGoalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _proteinWeekServings = proteinWeekServings;
          _proteinGoalValue = proteinGoalValue;
        });
      }

      // Load grains weekly data
      final grainsWeekServings = <double>[];
      double? grainsGoalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('grains');
          if (tracker != null) {
            grainsWeekServings.add(tracker.currentValue);
            grainsGoalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            grainsWeekServings.add(0.0);
          }
        } else {
          final p = grainsByDay[d];
          if (p != null) {
            grainsWeekServings.add(p.achievedValue);
            if (grainsGoalValue == null && p.targetValue > 0) {
              grainsGoalValue = p.targetValue;
            }
          } else {
            grainsWeekServings.add(0.0);
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEndGrains = grainsByDay[end];
      if (pEndGrains != null && pEndGrains.targetValue > 0) {
        grainsGoalValue = pEndGrains.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = grainsByDay[d];
          if (p != null && p.targetValue > 0) {
            grainsGoalValue = p.targetValue;
            break;
          }
        }
      }
      if (grainsGoalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('grains');
        if (tracker != null && tracker.goalValue > 0) {
          grainsGoalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _grainsWeekServings = grainsWeekServings;
          _grainsGoalValue = grainsGoalValue;
        });
      }

      // Load dairy weekly data
      final dairyWeekServings = <double>[];
      double? dairyGoalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('dairy');
          if (tracker != null) {
            dairyWeekServings.add(tracker.currentValue);
            dairyGoalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            dairyWeekServings.add(0.0);
          }
        } else {
          final p = dairyByDay[d];
          if (p != null) {
            dairyWeekServings.add(p.achievedValue);
            if (dairyGoalValue == null && p.targetValue > 0) {
              dairyGoalValue = p.targetValue;
            }
          } else {
            dairyWeekServings.add(0.0);
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEndDairy = dairyByDay[end];
      if (pEndDairy != null && pEndDairy.targetValue > 0) {
        dairyGoalValue = pEndDairy.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = dairyByDay[d];
          if (p != null && p.targetValue > 0) {
            dairyGoalValue = p.targetValue;
            break;
          }
        }
      }
      if (dairyGoalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('dairy');
        if (tracker != null && tracker.goalValue > 0) {
          dairyGoalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _dairyWeekServings = dairyWeekServings;
          _dairyGoalValue = dairyGoalValue;
        });
      }

      // Load fats/oils weekly data
      final fatsOilsWeekServings = <double>[];
      double? fatsOilsGoalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('fatsOils');
          if (tracker != null) {
            fatsOilsWeekServings.add(tracker.currentValue);
            fatsOilsGoalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            fatsOilsWeekServings.add(0.0);
          }
        } else {
          final p = fatsOilsByDay[d];
          if (p != null) {
            fatsOilsWeekServings.add(p.achievedValue);
            if (fatsOilsGoalValue == null && p.targetValue > 0) {
              fatsOilsGoalValue = p.targetValue;
            }
          } else {
            fatsOilsWeekServings.add(0.0);
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEndFatsOils = fatsOilsByDay[end];
      if (pEndFatsOils != null && pEndFatsOils.targetValue > 0) {
        fatsOilsGoalValue = pEndFatsOils.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = fatsOilsByDay[d];
          if (p != null && p.targetValue > 0) {
            fatsOilsGoalValue = p.targetValue;
            break;
          }
        }
      }
      if (fatsOilsGoalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('fatsOils');
        if (tracker != null && tracker.goalValue > 0) {
          fatsOilsGoalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _fatsOilsWeekServings = fatsOilsWeekServings;
          _fatsOilsGoalValue = fatsOilsGoalValue;
        });
      }

      // Load sodium weekly data
      final sodiumWeekServings = <double>[];
      double? sodiumGoalValue;
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d == today && _todayTrackers != null && _todayTrackers!.isNotEmpty) {
          final tracker = _trackerForCategory('sodium');
          if (tracker != null) {
            sodiumWeekServings.add(tracker.currentValue);
            sodiumGoalValue ??= tracker.goalValue > 0 ? tracker.goalValue : null;
          } else {
            sodiumWeekServings.add(0.0);
          }
        } else {
          final p = sodiumByDay[d];
          if (p != null) {
            sodiumWeekServings.add(p.achievedValue);
            if (sodiumGoalValue == null && p.targetValue > 0) {
              sodiumGoalValue = p.targetValue;
            }
          } else {
            sodiumWeekServings.add(0.0);
          }
        }
      }
      // Prefer goal from selected date (end of week) so thresholds match that day
      final pEndSodium = sodiumByDay[end];
      if (pEndSodium != null && pEndSodium.targetValue > 0) {
        sodiumGoalValue = pEndSodium.targetValue;
      } else {
        for (int i = 5; i >= 0; i--) {
          final d = start.add(Duration(days: i));
          final p = sodiumByDay[d];
          if (p != null && p.targetValue > 0) {
            sodiumGoalValue = p.targetValue;
            break;
          }
        }
      }
      if (sodiumGoalValue == null && _todayTrackers != null) {
        final tracker = _trackerForCategory('sodium');
        if (tracker != null && tracker.goalValue > 0) {
          sodiumGoalValue = tracker.goalValue;
        }
      }
      if (mounted) {
        setState(() {
          _sodiumWeekServings = sodiumWeekServings;
          _sodiumGoalValue = sodiumGoalValue;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _veggiesWeekServings = List.generate(7, (_) => 0.0);
          _veggiesGoalValue = _veggiesGoalValue;
          _fruitsWeekServings = List.generate(7, (_) => 0.0);
          _fruitsGoalValue = _fruitsGoalValue;
          _waterWeekServings = List.generate(7, (_) => 0.0);
          _waterGoalValue = _waterGoalValue;
          _proteinWeekServings = List.generate(7, (_) => 0.0);
          _proteinGoalValue = _proteinGoalValue;
          _grainsWeekServings = List.generate(7, (_) => 0.0);
          _grainsGoalValue = _grainsGoalValue;
          _dairyWeekServings = List.generate(7, (_) => 0.0);
          _dairyGoalValue = _dairyGoalValue;
          _fatsOilsWeekServings = List.generate(7, (_) => 0.0);
          _fatsOilsGoalValue = _fatsOilsGoalValue;
          _sodiumWeekServings = List.generate(7, (_) => 0.0);
          _sodiumGoalValue = _sodiumGoalValue;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final firstDate = widget.accountCreatedAt != null
        ? DateTime(widget.accountCreatedAt!.year, widget.accountCreatedAt!.month, widget.accountCreatedAt!.day)
        : DateTime(2020);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate.isAfter(yesterday) ? yesterday : firstDate,
      lastDate: yesterday,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      await _loadProgressForDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () {
            // Always return to main dashboard/home when leaving history.
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Goal Progress',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateSelector(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Could not load history',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadProgressForDate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6A00),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildBarList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final maxSelectableDate = todayStart.subtract(const Duration(days: 1));
    final canGoForward = _selectedDate.isBefore(maxSelectableDate);

    final minSelectableDate = widget.accountCreatedAt != null
        ? DateTime(widget.accountCreatedAt!.year, widget.accountCreatedAt!.month, widget.accountCreatedAt!.day)
        : DateTime(2020);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final canGoBack = selectedDay.isAfter(minSelectableDate);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          canGoBack
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                    _loadProgressForDate();
                  },
                  icon: const Icon(Icons.chevron_left),
                  color: const Color(0xFFFF6A00),
                )
              : const SizedBox(width: 48),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    _dateLabel(_selectedDate),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
          ),
          canGoForward
              ? IconButton(
                  onPressed: () {
                    final nextDay = _selectedDate.add(const Duration(days: 1));
                    if (nextDay.isBefore(todayStart)) {
                      setState(() => _selectedDate = nextDay);
                      _loadProgressForDate();
                    }
                  },
                  icon: const Icon(Icons.chevron_right),
                  color: const Color(0xFFFF6A00),
                )
              : const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Per category, the latest progress for the selected day (by createdAt).
  TrackerProgress? _progressForCategory(String categoryKey) {
    TrackerProgress? found;
    for (final p in _progressList) {
      final key = p.trackerCategory;
      final norm = key.contains('.') ? key.split('.').last : key;
      // For DASH, protein is stored as leanMeat in trackerCategory.
      final isMatch = norm == categoryKey ||
          (categoryKey == 'protein' && norm == 'leanMeat');
      if (isMatch) {
        if (found == null || p.createdAt.isAfter(found.createdAt)) {
          found = p;
        }
      }
    }
    return found;
  }

  TrackerGoal? _trackerForCategory(String categoryKey) {
    if (_todayTrackers == null) return null;
    for (final t in _todayTrackers!) {
      final key = t.category.toString().split('.').last;
      if (key == categoryKey) return t;
      if (categoryKey == 'protein' && key == 'leanMeat') return t;
    }
    return null;
  }

  Widget _buildBarList() {
    final useTodayTrackers = _todayTrackers != null;
    final bool showLastLoggedHeader =
        !useTodayTrackers && _progressList.isEmpty && _lastLoggedDateForSelected != null;
    final bool hasDataForSelectedDate = !useTodayTrackers && _progressList.isNotEmpty;
    final String headerText;
    if (useTodayTrackers) {
      headerText = 'Current goals for ${_dateLabel(_selectedDate)}';
    } else if (showLastLoggedHeader) {
      headerText = 'Last logged on ${_dateLabel(_lastLoggedDateForSelected!)}';
    } else {
      // No data for this date and no earlier logs — encourage first log
      headerText = 'Start logging to see progress';
    }
    final bool showHeaderLine = !hasDataForSelectedDate;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (showHeaderLine) ...[
          Text(
            headerText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ..._effectiveCategoryOrder.map((catKey) {
          if (useTodayTrackers) {
            final t = _trackerForCategory(catKey);
            return _buildHistoryRowFromTracker(catKey, t);
          }
          final p = _progressForCategory(catKey);
          return _buildHistoryRow(catKey, p);
        }),
        const SizedBox(height: 24),
        const Text(
          'Weekly Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        _buildWeeklyGraphCarousel(),
      ],
    );
  }

  Widget _buildHistoryRowFromTracker(String categoryKey, TrackerGoal? tracker) {
    final category = _categoryFromString(categoryKey);
    final name = _displayName(categoryKey);
    final target = tracker?.goalValue ?? 0.0;
    final achieved = tracker?.currentValue ?? 0.0;
    final progressRatio = target > 0 ? (achieved / target) : 0.0;
    final hasData = tracker != null;
    final color = hasData
        ? TrackerCard.getProgressColor(
            progressRatio,
            category,
            goalValue: target,
          )
        : Colors.grey;
    final unit = tracker != null ? tracker.unitString : _defaultUnit(categoryKey);
    final valueText = hasData
        ? '${_formatNum(achieved)}/${_formatNum(target)} $unit'
        : 'No data';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildCategoryIcon(category),
            const SizedBox(width: 12),
            Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressRatio > 1.0 ? 1.0 : progressRatio,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueText,
              style: TextStyle(
                fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (hasData)
              Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(String categoryKey, TrackerProgress? progress) {
    final category = _categoryFromString(categoryKey);
    final name = _displayName(categoryKey);
    final target = progress?.targetValue ?? 0.0;
    final achieved = progress?.achievedValue ?? 0.0;
    final progressRatio = target > 0 ? (achieved / target) : 0.0;
    final hasData = progress != null && target > 0;
    final color = hasData
                    ? TrackerCard.getProgressColor(
            progressRatio,
            category,
            goalValue: target,
          )
        : Colors.grey;
    final unit = progress != null
        ? _formatUnit(progress.unit)
        : _defaultUnit(categoryKey);
    final valueText = hasData
        ? '${_formatNum(achieved)}/${_formatNum(target)} $unit'
        : 'No data';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildCategoryIcon(category),
            const SizedBox(width: 12),
            Expanded(
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressRatio > 1.0 ? 1.0 : progressRatio,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                        Text(
                    valueText,
                          style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (hasData)
                        Text(
                'Logged',
                          style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                          ),
              )
            else
              const SizedBox.shrink(),
                      ],
                    ),
                  ),
                );
  }

  /// Returns closest point index (0-6) if local position is near a point, else null.
  int? _getVeggiesChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    const chartPadding = 4.0;
    final axisGoal = _veggiesGoalValue ?? 5.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _veggiesWeekServings.length;
    if (n < 2) return null;

    double valueToY(double v) {
      final ratio = v.clamp(0.0, axisGoal) / axisGoal;
      return chartRect.bottom - ratio * chartRect.height;
    }

    int? closest;
    double minDist = 40.0; // max hit radius
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_veggiesWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  /// Returns the local offset of the data point at index (for tooltip positioning).
  Offset _getVeggiesChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    const chartPadding = 4.0;
    final axisGoal = _veggiesGoalValue ?? 5.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _veggiesWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, axisGoal) / axisGoal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_veggiesWeekServings[index]);
    return Offset(x, y);
  }

  void _showVeggiesPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showVeggiesTooltipAtPoint(context, index, chartSize, labelCenterXs);
    // On tap (mobile), auto-dismiss after 2.5s
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeVeggiesHoverOverlay();
    });
  }

  void _showVeggiesTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getVeggiesChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);

    final val = _veggiesWeekServings[index];
    final axisGoal = _veggiesGoalValue ?? 5.0;
    final text = '${_formatNum(val)}/${_formatNum(axisGoal)}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.veggies,
      goalValue: axisGoal,
    );

    _veggiesHoverOverlay?.remove();
    _veggiesHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_veggiesHoverOverlay!);
  }

  void _removeVeggiesHoverOverlay() {
    _veggiesHoverOverlay?.remove();
    _veggiesHoverOverlay = null;
  }

  int? _getFruitsChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _fruitsGoalValue ?? 4.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _fruitsWeekServings.length;
    if (n < 2) return null;
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    int? closest;
    double minDist = 40.0;
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_fruitsWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  Offset _getFruitsChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _fruitsGoalValue ?? 4.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _fruitsWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_fruitsWeekServings[index]);
    return Offset(x, y);
  }

  void _showFruitsPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showFruitsTooltipAtPoint(context, index, chartSize, labelCenterXs);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeFruitsHoverOverlay();
    });
  }

  void _showFruitsTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getFruitsChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);

    final val = _fruitsWeekServings[index];
    final axisGoal = _fruitsGoalValue ?? 4.0;
    final text = '${_formatNum(val)}/${axisGoal.toInt()}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.fruits,
      goalValue: axisGoal,
    );

    _fruitsHoverOverlay?.remove();
    _fruitsHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_fruitsHoverOverlay!);
  }

  void _removeFruitsHoverOverlay() {
    _fruitsHoverOverlay?.remove();
    _fruitsHoverOverlay = null;
  }

  int? _getWaterChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _waterGoalValue ?? 8.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _waterWeekServings.length;
    if (n < 2) return null;
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    int? closest;
    double minDist = 40.0;
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_waterWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  Offset _getWaterChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _waterGoalValue ?? 8.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _waterWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_waterWeekServings[index]);
    return Offset(x, y);
  }

  void _showWaterPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showWaterTooltipAtPoint(context, index, chartSize, labelCenterXs);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeWaterHoverOverlay();
    });
  }

  void _showWaterTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getWaterChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);

    final val = _waterWeekServings[index];
    final axisGoal = _waterGoalValue ?? 8.0;
    final text = '${_formatNum(val)}/${axisGoal.toInt()}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.water,
      goalValue: axisGoal,
    );

    _waterHoverOverlay?.remove();
    _waterHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_waterHoverOverlay!);
  }

  void _removeWaterHoverOverlay() {
    _waterHoverOverlay?.remove();
    _waterHoverOverlay = null;
  }

  int? _getProteinChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _proteinGoalValue ?? 6.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _proteinWeekServings.length;
    if (n < 2) return null;
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    int? closest;
    double minDist = 40.0;
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_proteinWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  Offset _getProteinChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _proteinGoalValue ?? 6.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _proteinWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_proteinWeekServings[index]);
    return Offset(x, y);
  }

  void _showProteinPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showProteinTooltipAtPoint(context, index, chartSize, labelCenterXs);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeProteinHoverOverlay();
    });
  }

  void _showProteinTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getProteinChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);

    final val = _proteinWeekServings[index];
    final axisGoal = _proteinGoalValue ?? 6.0;
    final text = '${_formatNum(val)}/${axisGoal.toInt()}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.protein,
      goalValue: axisGoal,
    );

    _proteinHoverOverlay?.remove();
    _proteinHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_proteinHoverOverlay!);
  }

  void _removeProteinHoverOverlay() {
    _proteinHoverOverlay?.remove();
    _proteinHoverOverlay = null;
  }

  int? _getGrainsChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _grainsGoalValue ?? 6.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _grainsWeekServings.length;
    if (n < 2) return null;
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    int? closest;
    double minDist = 40.0;
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_grainsWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  Offset _getGrainsChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _grainsGoalValue ?? 6.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _grainsWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_grainsWeekServings[index]);
    return Offset(x, y);
  }

  void _showGrainsPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showGrainsTooltipAtPoint(context, index, chartSize, labelCenterXs);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeGrainsHoverOverlay();
    });
  }

  void _showGrainsTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getGrainsChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);
    final val = _grainsWeekServings[index];
    final axisGoal = _grainsGoalValue ?? 6.0;
    final text = '${_formatNum(val)}/${axisGoal.toInt()}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.grains,
      goalValue: axisGoal,
    );
    _grainsHoverOverlay?.remove();
    _grainsHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_grainsHoverOverlay!);
  }

  void _removeGrainsHoverOverlay() {
    _grainsHoverOverlay?.remove();
    _grainsHoverOverlay = null;
  }

  int? _getDairyChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _dairyGoalValue ?? 3.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _dairyWeekServings.length;
    if (n < 2) return null;
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    int? closest;
    double minDist = 40.0;
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_dairyWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  Offset _getDairyChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _dairyGoalValue ?? 3.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _dairyWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_dairyWeekServings[index]);
    return Offset(x, y);
  }

  void _showDairyPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showDairyTooltipAtPoint(context, index, chartSize, labelCenterXs);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeDairyHoverOverlay();
    });
  }

  void _showDairyTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getDairyChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);
    final val = _dairyWeekServings[index];
    final axisGoal = _dairyGoalValue ?? 3.0;
    final text = '${_formatNum(val)}/${axisGoal.toInt()}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.dairy,
      goalValue: axisGoal,
    );
    _dairyHoverOverlay?.remove();
    _dairyHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_dairyHoverOverlay!);
  }

  void _removeDairyHoverOverlay() {
    _dairyHoverOverlay?.remove();
    _dairyHoverOverlay = null;
  }

  int? _getFatsOilsChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _fatsOilsGoalValue ?? 2.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _fatsOilsWeekServings.length;
    if (n < 2) return null;
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    int? closest;
    double minDist = 40.0;
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_fatsOilsWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  Offset _getFatsOilsChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _fatsOilsGoalValue ?? 2.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _fatsOilsWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_fatsOilsWeekServings[index]);
    return Offset(x, y);
  }

  void _showFatsOilsPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showFatsOilsTooltipAtPoint(context, index, chartSize, labelCenterXs);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeFatsOilsHoverOverlay();
    });
  }

  void _showFatsOilsTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getFatsOilsChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);
    final val = _fatsOilsWeekServings[index];
    final axisGoal = _fatsOilsGoalValue ?? 2.0;
    final text = '${_formatNum(val)}/${axisGoal.toInt()}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.fatsOils,
      goalValue: axisGoal,
    );
    _fatsOilsHoverOverlay?.remove();
    _fatsOilsHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_fatsOilsHoverOverlay!);
  }

  void _removeFatsOilsHoverOverlay() {
    _fatsOilsHoverOverlay?.remove();
    _fatsOilsHoverOverlay = null;
  }

  int? _getSodiumChartClosestPointIndex(
    Offset localPos,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _sodiumGoalValue ?? 2300.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _sodiumWeekServings.length;
    if (n < 2) return null;
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    int? closest;
    double minDist = 40.0;
    for (int i = 0; i < n; i++) {
      final x = labelCenterXs.length > i
          ? innerLeft + labelCenterXs[i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(_sodiumWeekServings[i]);
      final d = (Offset(x, y) - localPos).distance;
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  Offset _getSodiumChartPointOffset(
    int index,
    double width,
    double height,
    List<double> labelCenterXs,
  ) {
    final goal = _sodiumGoalValue ?? 2300.0;
    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      width - chartPadding * 2,
      height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = _sodiumWeekServings.length;
    if (n < 2 || index < 0 || index >= n) return Offset.zero;
    final x = labelCenterXs.length > index
        ? innerLeft + labelCenterXs[index]
        : innerLeft + (innerWidth / n) * (index + 0.5);
    double valueToY(double v) {
      final ratio = v.clamp(0.0, goal) / goal;
      return chartRect.bottom - ratio * chartRect.height;
    }
    final y = valueToY(_sodiumWeekServings[index]);
    return Offset(x, y);
  }

  void _showSodiumPointTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    _showSodiumTooltipAtPoint(context, index, chartSize, labelCenterXs);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeSodiumHoverOverlay();
    });
  }

  void _showSodiumTooltipAtPoint(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pointLocal = _getSodiumChartPointOffset(
      index,
      chartSize.width,
      chartSize.height,
      labelCenterXs,
    );
    final globalPos = box.localToGlobal(pointLocal);
    final val = _sodiumWeekServings[index];
    final axisGoal = _sodiumGoalValue ?? 2300.0;
    final text = '${_formatNum(val)}/${axisGoal.toInt()}';
    final progress = axisGoal > 0 ? val / axisGoal : 0.0;
    final valueColor = TrackerCard.getProgressColor(
      progress,
      TrackerCategory.sodium,
      goalValue: axisGoal,
    );
    _sodiumHoverOverlay?.remove();
    _sodiumHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 35,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFE8E8E8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_sodiumHoverOverlay!);
  }

  void _removeSodiumHoverOverlay() {
    _sodiumHoverOverlay?.remove();
    _sodiumHoverOverlay = null;
  }

  /// Y-axis labels positioned beside the threshold lines (matches painter coordinate system).
  static const double _chartHeight = 160.0;
  static const double _chartPadding = 4.0;

  Widget _buildYAxisLabels(double goal, double halfGoal, {double? yellowThreshold}) {
    final nearGoal = yellowThreshold ?? (goal - 0.5).clamp(0.0, goal);
    final chartRectHeight = _chartHeight - _chartPadding * 2;
    final chartRectBottom = _chartHeight - _chartPadding;

    double valueToY(double v) =>
        chartRectBottom - (v / goal) * chartRectHeight;

    const fontSize = 11.0;
    const halfTextHeight = fontSize / 2;

    return SizedBox(
      width: 28,
      height: _chartHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: valueToY(goal) - halfTextHeight,
            child: Text(
              _formatNum(goal),
              style: const TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Color(0xFF09B26B),
              ),
            ),
          ),
          if (nearGoal > halfGoal && nearGoal < goal)
            Positioned(
              right: 0,
              top: valueToY(nearGoal) - halfTextHeight,
            child: Text(
              _formatNum(nearGoal),
              style: const TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFA000),
              ),
            ),
            ),
          Positioned(
            right: 0,
            top: valueToY(halfGoal) - halfTextHeight,
            child: Text(
              _formatNum(halfGoal),
              style: const TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6A00),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: valueToY(0) - halfTextHeight,
            child: const Text(
              '0',
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty-state card for weekly graph when no data.
  Widget _buildEmptyWeeklyGraphCard(String title) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Servings per day',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
                SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No data for this week',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
                    ],
                  ),
                ),
    );
  }

  /// Carousel of weekly graph cards with < and > arrows overlaid on the card.
  /// Cards are diet-aware: DASH/Diabetes include Fats/Oils; MyPlate has 7 categories.
  /// Arrows appear on hover (desktop) or tap (mobile) and hide when cursor/pointer leaves.
  Widget _buildWeeklyGraphCarousel() {
    final cards = _effectiveCategoryOrder.map((catKey) {
      switch (catKey) {
        case 'veggies': return _buildVeggiesWeeklyGraphCard();
        case 'fruits': return _buildFruitsWeeklyGraphCard();
        case 'protein': return _buildProteinWeeklyGraphCard();
        case 'grains': return _buildGrainsWeeklyGraphCard();
        case 'dairy': return _buildDairyWeeklyGraphCard();
        case 'fatsOils': return _buildFatsOilsWeeklyGraphCard();
        case 'water': return _buildWaterWeeklyGraphCard();
        case 'sodium': return _buildSodiumWeeklyGraphCard();
        default: return const SizedBox.shrink();
      }
    }).toList();
    final showPrev = _weeklyGraphPageIndex > 0;
    final showNext = _weeklyGraphPageIndex < _weeklyGraphCount - 1;

    return MouseRegion(
      onEnter: (_) {
        _carouselArrowsHideTimer?.cancel();
        if (!_showCarouselArrows && mounted) setState(() => _showCarouselArrows = true);
      },
      onExit: (_) {
        _carouselArrowsHideTimer?.cancel();
        if (_showCarouselArrows && mounted) setState(() => _showCarouselArrows = false);
      },
      child: GestureDetector(
        onTapDown: (_) => _showCarouselArrowsTemporarily(),
        child: SizedBox(
          height: 295,
          child: Stack(
                            children: [
              PageView.builder(
                controller: _weeklyGraphPageController,
                itemCount: _weeklyGraphCount,
                onPageChanged: (i) => setState(() => _weeklyGraphPageIndex = i),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: cards[index],
                ),
              ),
              if (_showCarouselArrows && showPrev)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.white.withOpacity(0.85),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (_weeklyGraphPageIndex > 0) {
                            _weeklyGraphPageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.chevron_left, color: Color(0xFF4294FF), size: 28),
                                    ),
                                  ),
                                ),
                              ),
                ),
              if (_showCarouselArrows && showNext)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.white.withOpacity(0.85),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (_weeklyGraphPageIndex < _weeklyGraphCount - 1) {
                            _weeklyGraphPageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.chevron_right, color: Color(0xFF4294FF), size: 28),
                    ),
                  ),
                ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Veggies weekly line graph (this week) shown at the bottom of the history page.
  Widget _buildVeggiesWeeklyGraphCard() {
    final goal = _veggiesGoalValue;
    // Show graph if we have a goal; otherwise show empty-state card.
    if (goal == null || goal <= 0) {
      return _buildEmptyWeeklyGraphCard('Veggies');
    }

    // Use user's diet plan goal for axis and threshold lines
    final axisGoal = goal;
    final halfAxisGoal = axisGoal / 2;
    final end =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veggies',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Servings per day',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chart + date labels (same width)
                Expanded(
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                        height: 160,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            const h = 160.0;
                            final chartInnerWidth = (w - 8) * 0.98;
                            final labelCenterXs = _MealGoalsHistoryPageState._computeDateLabelCenterXs(
                              7,
                              chartInnerWidth,
                            );
                            return GestureDetector(
                              onTapUp: (details) {
                                final index = _getVeggiesChartClosestPointIndex(
                                  details.localPosition,
                                  w,
                                  h,
                                  labelCenterXs,
                                );
                                if (index != null && context.mounted) {
                                  _showVeggiesPointTooltip(
                                    context,
                                    index,
                                    Size(w, h),
                                    labelCenterXs,
                                  );
                                }
                              },
                              child: CustomPaint(
                                  painter: _VeggiesWeekLineChartPainter(
                                    values: _veggiesWeekServings,
                                    goal: axisGoal,
                                    halfGoal: halfAxisGoal,
                                    labelCenterXs: labelCenterXs,
                                  ),
                                ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // X-axis: 7 days spread across 98% to match chart inner area
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chartWidth = constraints.maxWidth;
                          final innerWidth = (chartWidth - 8) * 0.98;
                          final slotWidth = innerWidth / 7;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: innerWidth,
                              child: Row(
                                children: List.generate(7, (index) {
                                  final d = start.add(Duration(days: index));
                                  return SizedBox(
                                    width: slotWidth,
                                    child: Center(
                                      child: Text(
                                        '${d.month}/${d.day}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
                ),
                const SizedBox(width: 8),
                _buildYAxisLabels(axisGoal, halfAxisGoal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fruits weekly line graph (this week).
  Widget _buildFruitsWeeklyGraphCard() {
    final goal = _fruitsGoalValue;
    if (goal == null || goal <= 0) {
      return _buildEmptyWeeklyGraphCard('Fruits');
    }

    final halfGoalValue = goal / 2;
    final end =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fruits',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Servings per day',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                    children: [
                              SizedBox(
                        height: 160,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            const h = 160.0;
                            final chartInnerWidth = (w - 8) * 0.98;
                            final labelCenterXs = _MealGoalsHistoryPageState._computeDateLabelCenterXs(
                              7,
                              chartInnerWidth,
                            );
                            return GestureDetector(
                              onTapUp: (details) {
                                final index = _getFruitsChartClosestPointIndex(
                                  details.localPosition,
                                  w,
                                  h,
                                  labelCenterXs,
                                );
                                if (index != null && context.mounted) {
                                  _showFruitsPointTooltip(
                                    context,
                                    index,
                                    Size(w, h),
                                    labelCenterXs,
                                  );
                                }
                              },
                              child: CustomPaint(
                                painter: _VeggiesWeekLineChartPainter(
                                  values: _fruitsWeekServings,
                                  goal: goal,
                                  halfGoal: halfGoalValue,
                                  labelCenterXs: labelCenterXs,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chartWidth = constraints.maxWidth;
                          final innerWidth = (chartWidth - 8) * 0.98;
                          final slotWidth = innerWidth / 7;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: innerWidth,
                  child: Row(
                                children: List.generate(7, (index) {
                                  final d = start.add(Duration(days: index));
                                  return SizedBox(
                                    width: slotWidth,
                                    child: Center(
                                      child: Text(
                                        '${d.month}/${d.day}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                ),
                              ),
                            ),
                                  );
                                }),
                          ),
                          ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildYAxisLabels(goal, halfGoalValue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Water weekly line graph (this week).
  Widget _buildWaterWeeklyGraphCard() {
    final goal = _waterGoalValue;
    if (goal == null || goal <= 0) {
      return _buildEmptyWeeklyGraphCard('Water');
    }

    final halfGoalValue = goal / 2;
    final end =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Water',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cups per day',
                style: TextStyle(
                  fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                        height: 160,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            const h = 160.0;
                            final chartInnerWidth = (w - 8) * 0.98;
                            final labelCenterXs = _MealGoalsHistoryPageState._computeDateLabelCenterXs(
                              7,
                              chartInnerWidth,
                            );
                            return GestureDetector(
                              onTapUp: (details) {
                                final index = _getWaterChartClosestPointIndex(
                                  details.localPosition,
                                  w,
                                  h,
                                  labelCenterXs,
                                );
                                if (index != null && context.mounted) {
                                  _showWaterPointTooltip(
                                    context,
                                    index,
                                    Size(w, h),
                                    labelCenterXs,
                                  );
                                }
                              },
                              child: CustomPaint(
                                painter: _VeggiesWeekLineChartPainter(
                                  values: _waterWeekServings,
                                  goal: goal,
                                  halfGoal: halfGoalValue,
                                  labelCenterXs: labelCenterXs,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chartWidth = constraints.maxWidth;
                          final innerWidth = (chartWidth - 8) * 0.98;
                          final slotWidth = innerWidth / 7;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: innerWidth,
                              child: Row(
                                children: List.generate(7, (index) {
                                  final d = start.add(Duration(days: index));
                                  return SizedBox(
                                    width: slotWidth,
                                    child: Center(
                                      child: Text(
                                        '${d.month}/${d.day}',
                                        style: const TextStyle(
                                          fontSize: 11,
                  fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildYAxisLabels(goal, halfGoalValue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Protein weekly line graph (this week).
  Widget _buildProteinWeeklyGraphCard() {
    final goal = _proteinGoalValue;
    if (goal == null || goal <= 0) {
      return _buildEmptyWeeklyGraphCard('Protein');
    }

    final halfGoalValue = goal / 2;
    final end =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            const Text(
              'Protein',
          style: TextStyle(
            fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'oz per day',
              style: TextStyle(
                fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 160,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            const h = 160.0;
                            final chartInnerWidth = (w - 8) * 0.98;
                            final labelCenterXs = _MealGoalsHistoryPageState._computeDateLabelCenterXs(
                              7,
                              chartInnerWidth,
                            );
                            return GestureDetector(
                              onTapUp: (details) {
                                final index = _getProteinChartClosestPointIndex(
                                  details.localPosition,
                                  w,
                                  h,
                                  labelCenterXs,
                                );
                                if (index != null && context.mounted) {
                                  _showProteinPointTooltip(
                                    context,
                                    index,
                                    Size(w, h),
                                    labelCenterXs,
                                  );
                                }
                              },
                              child: CustomPaint(
                                painter: _VeggiesWeekLineChartPainter(
                                  values: _proteinWeekServings,
                                  goal: goal,
                                  halfGoal: halfGoalValue,
                                  labelCenterXs: labelCenterXs,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chartWidth = constraints.maxWidth;
                          final innerWidth = (chartWidth - 8) * 0.98;
                          final slotWidth = innerWidth / 7;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: innerWidth,
                              child: Row(
                                children: List.generate(7, (index) {
                                  final d = start.add(Duration(days: index));
                                  return SizedBox(
                                    width: slotWidth,
                                    child: Center(
                                      child: Text(
                                        '${d.month}/${d.day}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildYAxisLabels(goal, halfGoalValue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Grains weekly line graph (this week). Same color logic as Protein (orange/yellow/green/red).
  Widget _buildGrainsWeeklyGraphCard() {
    final goal = _grainsGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Grains');
    final halfGoalValue = goal / 2;
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));
    return _buildWeeklyGraphCard(
      title: 'Grains',
      subtitle: 'oz per day',
      values: _grainsWeekServings,
      goal: goal,
      halfGoalValue: halfGoalValue,
      start: start,
      getClosestIndex: _getGrainsChartClosestPointIndex,
      showTooltip: _showGrainsPointTooltip,
    );
  }

  /// Dairy weekly line graph (this week). Same color logic as Protein.
  Widget _buildDairyWeeklyGraphCard() {
    final goal = _dairyGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Dairy');
    final halfGoalValue = goal / 2;
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));
    return _buildWeeklyGraphCard(
      title: 'Dairy',
      subtitle: 'Cups per day',
      values: _dairyWeekServings,
      goal: goal,
      halfGoalValue: halfGoalValue,
      start: start,
      getClosestIndex: _getDairyChartClosestPointIndex,
      showTooltip: _showDairyPointTooltip,
    );
  }

  /// Sodium weekly line graph (this week). Special logic: Orange <50%, Yellow 50-75%, Green 75-100%, Red >100%.
  Widget _buildSodiumWeeklyGraphCard() {
    final goal = _sodiumGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Sodium');
    final halfGoalValue = goal / 2;
    final yellowThreshold = goal * 0.75; // Sodium: yellow at 75%, not nearGoal
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sodium',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 4),
            Text('mg per day', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Expanded(
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                children: [
                      SizedBox(
                        height: 160,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            const h = 160.0;
                            final chartInnerWidth = (w - 8) * 0.98;
                            final labelCenterXs = _MealGoalsHistoryPageState._computeDateLabelCenterXs(7, chartInnerWidth);
                            return GestureDetector(
                              onTapUp: (details) {
                                final index = _getSodiumChartClosestPointIndex(
                                  details.localPosition, w, h, labelCenterXs);
                                if (index != null && context.mounted) {
                                  _showSodiumPointTooltip(context, index, Size(w, h), labelCenterXs);
                                }
                              },
                              child: CustomPaint(
                                painter: _VeggiesWeekLineChartPainter(
                                  values: _sodiumWeekServings,
                                  goal: goal,
                                  halfGoal: halfGoalValue,
                                  labelCenterXs: labelCenterXs,
                                  yellowThresholdValue: yellowThreshold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final innerWidth = (constraints.maxWidth - 8) * 0.98;
                          final slotWidth = innerWidth / 7;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: innerWidth,
                              child: Row(
                                children: List.generate(7, (i) {
                                  final d = start.add(Duration(days: i));
                                  return SizedBox(
                                    width: slotWidth,
                                    child: Center(
                                      child: Text('${d.month}/${d.day}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black)),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
                const SizedBox(width: 8),
                _buildYAxisLabels(goal, halfGoalValue, yellowThreshold: yellowThreshold),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fats/Oils weekly line graph (this week). Same color logic as Protein.
  Widget _buildFatsOilsWeeklyGraphCard() {
    final goal = _fatsOilsGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Fats/Oils');
    final halfGoalValue = goal / 2;
    final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = end.subtract(const Duration(days: 6));
    return _buildWeeklyGraphCard(
      title: 'Fats/Oils',
      subtitle: 'Servings per day',
      values: _fatsOilsWeekServings,
      goal: goal,
      halfGoalValue: halfGoalValue,
      start: start,
      getClosestIndex: _getFatsOilsChartClosestPointIndex,
      showTooltip: _showFatsOilsPointTooltip,
    );
  }

  Widget _buildWeeklyGraphCard({
    required String title,
    required String subtitle,
    required List<double> values,
    required double goal,
    required double halfGoalValue,
    required DateTime start,
    required int? Function(Offset, double, double, List<double>) getClosestIndex,
    required void Function(BuildContext, int, Size, List<double>) showTooltip,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Expanded(
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                children: [
                      SizedBox(
                        height: 160,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            const h = 160.0;
                            final chartInnerWidth = (w - 8) * 0.98;
                            final labelCenterXs = _MealGoalsHistoryPageState._computeDateLabelCenterXs(7, chartInnerWidth);
                            return GestureDetector(
                              onTapUp: (details) {
                                final index = getClosestIndex(details.localPosition, w, h, labelCenterXs);
                                if (index != null && context.mounted) {
                                  showTooltip(context, index, Size(w, h), labelCenterXs);
                                }
                              },
                              child: CustomPaint(
                                painter: _VeggiesWeekLineChartPainter(
                                  values: values,
                                  goal: goal,
                                  halfGoal: halfGoalValue,
                                  labelCenterXs: labelCenterXs,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final innerWidth = (constraints.maxWidth - 8) * 0.98;
                          final slotWidth = innerWidth / 7;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: innerWidth,
                              child: Row(
                                children: List.generate(7, (i) {
                                  final d = start.add(Duration(days: i));
                                  return SizedBox(
                                    width: slotWidth,
                                    child: Center(
                                      child: Text('${d.month}/${d.day}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black)),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
                const SizedBox(width: 8),
                _buildYAxisLabels(goal, halfGoalValue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(TrackerCategory category) {
    final path = getTrackerIconAsset(category);
    if (path.endsWith('.svg')) {
      return SizedBox(
        width: 44,
        height: 44,
        child: SvgPicture.asset(path),
      );
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: Image.asset(path),
    );
  }

  String _displayName(String key) {
    switch (key) {
      case 'veggies':
        return 'Veggies';
      case 'fruits':
        return 'Fruits';
      case 'protein':
        return 'Protein';
      case 'grains':
        return 'Grains';
      case 'dairy':
        return 'Dairy';
      case 'fatsOils':
        return 'Fats/oils';
      case 'water':
        return 'Water';
      case 'sodium':
        return 'Sodium';
      default:
        return key;
    }
  }

  String _defaultUnit(String key) {
    if (key == 'sodium') return 'mg';
    if (key == 'water' || key == 'veggies' || key == 'fruits' || key == 'dairy') return 'Cups';
    if (key == 'protein' || key == 'grains') return 'oz';
    if (key == 'fatsOils') return 'Servings';
    return '';
  }

  String _formatNum(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    if ((v * 10) == (v * 10).truncateToDouble()) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  /// Center X of each date label when using 7 equal slots (matches date row with Center).
  static List<double> _computeDateLabelCenterXs(int count, double innerWidth) {
    if (count <= 0) return [];
    final slotWidth = innerWidth / count;
    return List.generate(count, (i) => slotWidth * (i + 0.5));
  }
}

/// Painter for the weekly veggies line chart with dotted goal/threshold lines.
class _VeggiesWeekLineChartPainter extends CustomPainter {
  final List<double> values;
  final double goal;
  final double halfGoal;
  /// Center X of each date label (0..innerWidth); when provided, dots align with dates.
  final List<double>? labelCenterXs;
  /// When provided (e.g. for sodium), use this for yellow line instead of (goal-0.5).clamp().
  final double? yellowThresholdValue;

  _VeggiesWeekLineChartPainter({
    required this.values,
    required this.goal,
    required this.halfGoal,
    this.labelCenterXs,
    this.yellowThresholdValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (goal <= 0 || values.isEmpty) return;

    final maxY = goal;
    final chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      size.width - chartPadding * 2,
      size.height - chartPadding * 2,
    );

    // Use a slightly narrower inner width for points/curve so the last point
    // does not sit directly on the Y-axis.
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;

    double valueToY(double v) {
      final clamped = v.clamp(0.0, maxY);
      final ratio = clamped / maxY;
      return chartRect.bottom - ratio * chartRect.height;
    }

    // Helper to draw a horizontal dashed line with a given color.
    void drawDashedLine(double y, Color color) {
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      double startX = chartRect.left;
      while (startX < chartRect.right) {
        final endX = (startX + dashWidth).clamp(chartRect.left, chartRect.right);
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
        startX += dashWidth + dashSpace;
      }
    }

    // Draw X and Y axes in black.
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;
    // X-axis (bottom)
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
    // Y-axis (right)
    canvas.drawLine(
      Offset(chartRect.right, chartRect.top),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    // Dotted threshold lines:
    // - Orange at 50% (orange/yellow boundary)
    // - Yellow: at yellowThresholdValue if provided (sodium 75%), else nearGoal = goal-0.5
    // - Green at 100% (green/red boundary)
    if (halfGoal > 0) {
      drawDashedLine(valueToY(halfGoal), const Color(0xFFFF6A00)); // orange
    }
    final yellowValue = yellowThresholdValue ?? (goal - 0.5).clamp(0.0, goal);
    if (yellowValue > halfGoal && yellowValue < goal) {
      drawDashedLine(valueToY(yellowValue), const Color(0xFFFFA800)); // yellow
    }
    drawDashedLine(valueToY(goal), const Color(0xFF2CCC87)); // green

    // Build points for all 7 days (null = 0)
    // Use labelCenterXs when provided (spaceBetween dates) so dots align with date centers
    final n = values.length;
    if (n < 2) return;
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final v = values[i];
      final x = labelCenterXs != null && i < labelCenterXs!.length
          ? innerLeft + labelCenterXs![i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      final y = valueToY(v);
      points.add(Offset(x, y));
    }

    // Draw path: straight line when adjacent points have same value, else smooth curve
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final v1 = values[i];
      final v2 = values[i + 1];
      // Straight line when both points have the same value (e.g. both zero)
      if ((v1 - v2).abs() < 0.001) {
        path.lineTo(p2.dx, p2.dy);
      } else {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];
        // Catmull-Rom to cubic bezier
        final cp1 = Offset(
          p1.dx + (p2.dx - p0.dx) / 6,
          p1.dy + (p2.dy - p0.dy) / 6,
        );
        final cp2 = Offset(
          p2.dx - (p3.dx - p1.dx) / 6,
          p2.dy - (p3.dy - p1.dy) / 6,
        );
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
    }

    // Convert to dashed path for dotted effect
    const dashLength = 4.0;
    const gapLength = 3.0;
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final nextDistance = (distance + dashLength).clamp(0.0, metric.length);
        dashedPath.addPath(
          metric.extractPath(distance, nextDistance),
          Offset.zero,
        );
        distance = nextDistance + gapLength;
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF007AFF) // brighter blue for stronger contrast
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(dashedPath, linePaint);

    final pointPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 4.0, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VeggiesWeekLineChartPainter oldDelegate) {
    if (oldDelegate.goal != goal || oldDelegate.halfGoal != halfGoal) return true;
    if (oldDelegate.yellowThresholdValue != yellowThresholdValue) return true;
    if (oldDelegate.labelCenterXs?.length != labelCenterXs?.length) return true;
    if (labelCenterXs != null && oldDelegate.labelCenterXs != null) {
      for (int i = 0; i < labelCenterXs!.length; i++) {
        if (i >= oldDelegate.labelCenterXs!.length ||
            (oldDelegate.labelCenterXs![i] - labelCenterXs![i]).abs() > 0.001) {
          return true;
        }
      }
    }
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
