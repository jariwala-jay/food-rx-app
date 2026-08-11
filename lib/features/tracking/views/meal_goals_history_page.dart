import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/core/widgets/tab_load_error_view.dart';
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

enum _WeeklyChartType { line, bar }

class _MealGoalsHistoryPageState extends State<MealGoalsHistoryPage> {
  final TrackerApiService _api = TrackerApiService();

  /// PRODUCT DECISION: Tracker days use a single global calendar anchored to
  /// America/New_York, not each user's device timezone. The daily/weekly
  /// Cloud Scheduler jobs (tracker-reset-daily / tracker-reset-weekly) run
  /// once for all users at the ET calendar boundary, so snapshots must
  /// represent the period being closed, not the cron execution timestamp
  /// (see _save_progress_snapshot_for_docs in backend/app/routers/trackers.py).
  /// This client uses the same timezone when determining calendar days and
  /// querying progress history.
  ///
  /// Do not replace this with DateTime.now() or device-local dates; doing so
  /// can shift snapshots and history by a day.
  static final tz.Location _appLocation = tz.getLocation('America/New_York');

  /// Current wall-clock time in the app's canonical timezone.
  DateTime get _appNow => tz.TZDateTime.now(_appLocation);

  /// Today's calendar day (y/m/d only) in the app's canonical timezone.
  DateTime get _appToday {
    final now = _appNow;
    return DateTime(now.year, now.month, now.day);
  }

  /// Which calendar day (in the app's canonical timezone) an arbitrary
  /// instant falls in — e.g. for converting accountCreatedAt or a
  /// progressDate into a comparable "day" marker.
  DateTime _etCalendarDay(DateTime instant) {
    final et = tz.TZDateTime.from(instant, _appLocation);
    return DateTime(et.year, et.month, et.day);
  }

  /// Midnight of [calendarDay] (a y/m/d marker in the app's canonical
  /// timezone), as a UTC instant — the boundary the progress API expects.
  DateTime _etMidnightUtc(DateTime calendarDay) => tz.TZDateTime(
        _appLocation,
        calendarDay.year,
        calendarDay.month,
        calendarDay.day,
      ).toUtc();

  /// Default to yesterday; Goal Progress shows data only through yesterday (today excluded).
  late DateTime _selectedDate;
  List<TrackerProgress> _progressList = [];
  List<TrackerGoal>? _todayTrackers;

  /// When there is no data for the selected date, this holds the most recent
  /// earlier date that has any logged progress (if found).
  DateTime? _lastLoggedDateForSelected;
  // Weekly history per category for the selected week. null = no data logged
  // that day (a gap in the chart); 0.0 = explicitly logged as zero (a
  // small visible mark, not a gap). Never conflate the two.
  List<double?> _veggiesWeekServings = List.filled(7, null);
  double? _veggiesGoalValue;
  List<double?> _fruitsWeekServings = List.filled(7, null);
  double? _fruitsGoalValue;
  List<double?> _waterWeekServings = List.filled(7, null);
  double? _waterGoalValue;
  List<double?> _proteinWeekServings = List.filled(7, null);
  double? _proteinGoalValue;
  List<double?> _grainsWeekServings = List.filled(7, null);
  double? _grainsGoalValue;
  List<double?> _dairyWeekServings = List.filled(7, null);
  double? _dairyGoalValue;
  List<double?> _fatsOilsWeekServings = List.filled(7, null);
  double? _fatsOilsGoalValue;
  List<double?> _sodiumWeekServings = List.filled(7, null);
  double? _sodiumGoalValue;

  /// Shared across categories — only one weekly-chart tooltip is ever shown
  /// at a time (the carousel only shows one category card at a time).
  OverlayEntry? _weeklyBarHoverOverlay;

  /// The actual start date of the current Weekly Summary window, computed by
  /// _loadWeekBarChartData (may be anchored to account creation, not always
  /// `end - 6 days`). Card builders must read this instead of re-deriving a
  /// start date from list length, since list length is always 7 either way.
  DateTime _weeklyGraphStart = DateTime(2020);
  bool _loading = true;
  String? _error;
  late PageController _weeklyGraphPageController;
  int _weeklyGraphPageIndex = 0;
  bool _showCarouselArrows = false;
  Timer? _carouselArrowsHideTimer;

  /// Which chart type is shown in the Weekly Summary cards. One shared
  /// choice for every category, held for the lifetime of this screen (not
  /// persisted across app launches).
  _WeeklyChartType _weeklyChartType = _WeeklyChartType.line;

  /// DASH and DiabetesPlate include Fats/Oils; MyPlate has 7 without Fats/Oils.
  List<String> get _effectiveCategoryOrder {
    final diet = (widget.dietType ?? '').toString();
    if (diet == 'DASH' || diet == 'DiabetesPlate') {
      return const [
        'veggies',
        'fruits',
        'protein',
        'grains',
        'dairy',
        'fatsOils',
        'water',
        'sodium',
      ];
    }
    return const [
      'veggies',
      'fruits',
      'protein',
      'grains',
      'dairy',
      'water',
      'sodium',
    ];
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _appToday.subtract(const Duration(days: 1));
    _weeklyGraphPageController = PageController();
    _weeklyGraphPageController.addListener(_onWeeklyGraphPageChanged);
    _loadProgressForDate();
  }

  int get _weeklyGraphCount => _effectiveCategoryOrder.length;

  void _onWeeklyGraphPageChanged() {
    if (!_weeklyGraphPageController.hasClients) return;
    final page = _weeklyGraphPageController.page?.round() ?? 0;
    if (page != _weeklyGraphPageIndex && mounted) {
      setState(
          () => _weeklyGraphPageIndex = page.clamp(0, _weeklyGraphCount - 1));
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
    if (!_showCarouselArrows && mounted) {
      setState(() => _showCarouselArrows = true);
    }
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
    final today = _appToday;
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
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
        final startUtc = _etMidnightUtc(_selectedDate);
        final endUtc =
            _etMidnightUtc(_selectedDate.add(const Duration(days: 1)))
                .subtract(const Duration(milliseconds: 1));
        final list = await _api.getProgress(
          periodType: 'daily',
          startDate: startUtc.toIso8601String(),
          endDate: endUtc.toIso8601String(),
        );
        DateTime? lastLoggedDate;
        if (list.isEmpty) {
          // Find the most recent earlier date (before the selected date) that has any progress.
          final historyStartDay = widget.accountCreatedAt != null
              ? _etCalendarDay(widget.accountCreatedAt!)
              : DateTime(2020);
          final history = await _api.getProgress(
            periodType: 'daily',
            startDate: _etMidnightUtc(historyStartDay).toIso8601String(),
            endDate: startUtc.toIso8601String(),
          );
          for (final p in history) {
            final d = _etCalendarDay(p.progressDate);
            if (d.isBefore(_selectedDate)) {
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
          _error = userFacingErrorMessage(e);
          _loading = false;
          _progressList = [];
          _todayTrackers = null;
        });
      }
    }
  }

  /// Category keys tracked in the Weekly Summary — canonical spelling used
  /// throughout this method (leanMeat progress records are folded into
  /// 'protein', matching _trackerForCategory's existing convention).
  static const List<String> _weeklyCategories = [
    'veggies',
    'fruits',
    'water',
    'protein',
    'grains',
    'dairy',
    'fatsOils',
    'sodium',
  ];

  /// Load a week of history per category for the Weekly Summary charts.
  ///
  /// This is strictly historical: a day with no saved progress record is
  /// left as `null` (a gap in the chart) — never substituted with today's
  /// live in-progress value and never defaulted to 0.0. An explicitly-logged
  /// 0 is real data and stays 0.0, distinct from `null`.
  Future<void> _loadWeekBarChartData() async {
    final end = _selectedDate;
    // Weekly Summary always shows a fixed 7-day window, but for a brand-new
    // account it's anchored to start at account creation (e.g. 8/3-8/9)
    // rather than trailing 7 days ending "today" (which would show empty
    // pre-signup days). Days in that window after `end` haven't happened yet
    // (or simply weren't logged) and are left as gaps — once the account is
    // a week old, this naturally becomes an ordinary trailing window again.
    final naturalStart = end.subtract(const Duration(days: 6));
    final accountCreatedDay = widget.accountCreatedAt != null
        ? _etCalendarDay(widget.accountCreatedAt!)
        : null;
    final start =
        (accountCreatedDay != null && accountCreatedDay.isAfter(naturalStart))
            ? accountCreatedDay
            : naturalStart;
    // Card builders read this instead of re-deriving a start date from list
    // length — list length is always 7 either way, so it can't tell them
    // which of the two formulas above actually produced `start`.
    _weeklyGraphStart = start;
    const daysCount = 7;
    try {
      final list = await _api.getProgress(
        periodType: 'daily',
        startDate: _etMidnightUtc(start).toIso8601String(),
        endDate:
            _etMidnightUtc(end.add(const Duration(days: 1))).toIso8601String(),
      );

      final byDayByCategory = <String, Map<DateTime, TrackerProgress>>{
        for (final c in _weeklyCategories) c: {},
      };
      for (final p in list) {
        final d = _etCalendarDay(p.progressDate);
        var key = p.trackerCategory.contains('.')
            ? p.trackerCategory.split('.').last
            : p.trackerCategory;
        if (key == 'leanMeat') key = 'protein';
        final byDay = byDayByCategory[key];
        if (byDay == null) continue; // unrecognized category — ignore
        final existing = byDay[d];
        if (existing == null || p.createdAt.isAfter(existing.createdAt)) {
          byDay[d] = p;
        }
      }

      final servingsByCategory = <String, List<double?>>{};
      final goalByCategory = <String, double?>{};
      for (final category in _weeklyCategories) {
        final byDay = byDayByCategory[category]!;
        final weekServings = <double?>[];
        double? goalValue;
        for (int i = 0; i < daysCount; i++) {
          final p = byDay[start.add(Duration(days: i))];
          if (p != null) {
            weekServings.add(p.achievedValue);
            goalValue ??= p.targetValue > 0 ? p.targetValue : null;
          } else {
            weekServings.add(null); // no record that day — a gap, not zero
          }
        }
        // Prefer the goal from the selected date (most relevant to what's
        // currently shown); fall back to the most recent earlier day's goal.
        final pEnd = byDay[end];
        if (pEnd != null && pEnd.targetValue > 0) {
          goalValue = pEnd.targetValue;
        } else {
          for (int i = daysCount - 2; i >= 0; i--) {
            final p = byDay[start.add(Duration(days: i))];
            if (p != null && p.targetValue > 0) {
              goalValue = p.targetValue;
              break;
            }
          }
        }
        // Last resort: the user's current goal, even if no history exists yet.
        if (goalValue == null && _todayTrackers != null) {
          final tracker = _trackerForCategory(category);
          if (tracker != null && tracker.goalValue > 0) {
            goalValue = tracker.goalValue;
          }
        }
        servingsByCategory[category] = weekServings;
        goalByCategory[category] = goalValue;
      }

      if (mounted) {
        setState(() {
          _veggiesWeekServings = servingsByCategory['veggies']!;
          _veggiesGoalValue = goalByCategory['veggies'];
          _fruitsWeekServings = servingsByCategory['fruits']!;
          _fruitsGoalValue = goalByCategory['fruits'];
          _waterWeekServings = servingsByCategory['water']!;
          _waterGoalValue = goalByCategory['water'];
          _proteinWeekServings = servingsByCategory['protein']!;
          _proteinGoalValue = goalByCategory['protein'];
          _grainsWeekServings = servingsByCategory['grains']!;
          _grainsGoalValue = goalByCategory['grains'];
          _dairyWeekServings = servingsByCategory['dairy']!;
          _dairyGoalValue = goalByCategory['dairy'];
          _fatsOilsWeekServings = servingsByCategory['fatsOils']!;
          _fatsOilsGoalValue = goalByCategory['fatsOils'];
          _sodiumWeekServings = servingsByCategory['sodium']!;
          _sodiumGoalValue = goalByCategory['sodium'];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _veggiesWeekServings = List.filled(daysCount, null);
          _fruitsWeekServings = List.filled(daysCount, null);
          _waterWeekServings = List.filled(daysCount, null);
          _proteinWeekServings = List.filled(daysCount, null);
          _grainsWeekServings = List.filled(daysCount, null);
          _dairyWeekServings = List.filled(daysCount, null);
          _fatsOilsWeekServings = List.filled(daysCount, null);
          _sodiumWeekServings = List.filled(daysCount, null);
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final yesterday = _appToday.subtract(const Duration(days: 1));
    final firstDate = widget.accountCreatedAt != null
        ? _etCalendarDay(widget.accountCreatedAt!)
        : DateTime(2020);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate.isAfter(yesterday) ? yesterday : firstDate,
      lastDate: yesterday,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF6A00),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C2C2C),
              onSurfaceVariant: Colors.white,
            ),
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: Colors.white,
              headerForegroundColor: Color(0xFF2C2C2C),
              weekdayStyle: TextStyle(color: Color(0xFF8E8E93)),
              dayStyle: TextStyle(color: Color(0xFF2C2C2C)),
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(Color(0xFFFF6A00)),
              ),
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(Color(0xFFFF6A00)),
              ),
            ),
          ),
          child: child!,
        );
      },
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
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Colors.black87),
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
      body: DefaultTextStyle.merge(
        // Bold is the default weight for all text on this page for
        // legibility. Text widgets that pin their own fontWeight (chart
        // labels, tooltips, etc.) override this merge and must set
        // FontWeight.bold explicitly, since an Overlay-rendered tooltip
        // in particular sits outside this widget's DefaultTextStyle scope.
        style: const TextStyle(fontWeight: FontWeight.bold),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isNewUserFirstDayEmpty) _buildDateSelector(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                      ),
                    )
                  : _error != null
                      ? TabLoadErrorView(
                          title: 'Unable to load progress',
                          onRetry: _loadProgressForDate,
                        )
                      : _buildBarList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final todayStart = _appToday;
    final maxSelectableDate = todayStart.subtract(const Duration(days: 1));
    final canGoForward = _selectedDate.isBefore(maxSelectableDate);

    final minSelectableDate = widget.accountCreatedAt != null
        ? _etCalendarDay(widget.accountCreatedAt!)
        : DateTime(2020);
    final selectedDay = _selectedDate;
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
                      _selectedDate =
                          _selectedDate.subtract(const Duration(days: 1));
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
                      fontWeight: FontWeight.bold,
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

  bool get _isAccountCreatedToday {
    final createdAt = widget.accountCreatedAt;
    if (createdAt == null) return false;
    final createdDay = _etCalendarDay(createdAt);
    final today = _appToday;
    return createdDay.year == today.year &&
        createdDay.month == today.month &&
        createdDay.day == today.day;
  }

  /// True when there's no historical data to browse at all yet — the account
  /// was created today, so the only selectable (pre-today) date predates it.
  bool get _isNewUserFirstDayEmpty =>
      _todayTrackers == null &&
      _progressList.isEmpty &&
      _lastLoggedDateForSelected == null &&
      _isAccountCreatedToday;

  Widget _buildBarList() {
    final useTodayTrackers = _todayTrackers != null;
    final bool showLastLoggedHeader = !useTodayTrackers &&
        _progressList.isEmpty &&
        _lastLoggedDateForSelected != null;
    final bool hasDataForSelectedDate =
        !useTodayTrackers && _progressList.isNotEmpty;

    if (_isNewUserFirstDayEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildNewUserEmptyState(),
        ),
      );
    }

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
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        _buildWeeklyGraphCarousel(),
      ],
    );
  }

  Widget _buildNewUserEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Your journey starts today!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          "Keep logging today's meals and your progress will appear here tomorrow.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6A00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Continue Tracking Today'),
        ),
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
    final unit =
        tracker != null ? tracker.unitString : _defaultUnit(categoryKey);
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
                      fontWeight: FontWeight.bold,
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
                      fontWeight: FontWeight.bold,
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
                      fontWeight: FontWeight.bold,
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
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Weekly Summary charts: shared hit-testing, tooltip and Y-axis ----

  double _weeklyChartMax(List<double?> values, double goal) {
    double maxLogged = 0.0;
    for (final v in values) {
      if (v != null && v > maxLogged) maxLogged = v;
    }
    final base = goal > maxLogged ? goal : maxLogged;
    return base > 0 ? base * 1.15 : 1.0;
  }

  /// Rounds a Y-axis step to a "nice" 1/2/5×10^n number, so a goal of 8
  /// yields ticks 0,2,4,6,8 and a goal of 5 yields 0,1,2,3,4,5.
  double _niceAxisStep(double max, {int targetTicks = 4}) {
    if (max <= 0) return 1;
    final raw = max / targetTicks;
    double mag = 1;
    while (mag * 10 <= raw) {
      mag *= 10;
    }
    while (mag > raw) {
      mag /= 10;
    }
    final norm = raw / mag;
    final step = norm < 1.5
        ? 1.0
        : norm < 3
            ? 2.0
            : norm < 7
                ? 5.0
                : 10.0;
    return step * mag;
  }

  /// Which day-slot (bar or gap) was tapped — pure X-proximity, so tapping
  /// anywhere in a day's column (including above a short bar, or a gap with
  /// no bar at all) registers as tapping that day.
  int? _getWeeklyBarIndexAt(Offset localPos, List<double> labelCenterXs) {
    const chartPadding = 4.0;
    int? closest;
    double minDist = 26.0;
    for (int i = 0; i < labelCenterXs.length; i++) {
      final x = chartPadding + labelCenterXs[i];
      final d = (x - localPos.dx).abs();
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return closest;
  }

  String _weeklyStatusLabel(Color color) {
    if (color == const Color(0xFF2CCC87)) return 'On Track';
    if (color == const Color(0xFFFFA800)) return 'Moderate';
    if (color == const Color(0xFFFF6A00)) return 'Low';
    return 'Over';
  }

  void _showWeeklyBarTooltip(
    BuildContext context,
    int index,
    Size chartSize,
    List<double> labelCenterXs,
    List<double?> values,
    double goal,
    TrackerCategory category,
    DateTime start,
  ) {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    const chartPadding = 4.0;
    final chartMax = _weeklyChartMax(values, goal);
    final x = chartPadding +
        (labelCenterXs.length > index ? labelCenterXs[index] : 0);
    final v = values[index];
    final date = start.add(Duration(days: index));
    if (v == null && !date.isBefore(_appToday)) return;

    final chartRectBottom = chartSize.height - chartPadding;
    final chartRectHeight = chartSize.height - chartPadding * 2;
    final y = v != null
        ? chartRectBottom -
            (v.clamp(0.0, chartMax) / chartMax) * chartRectHeight
        : chartRectBottom;
    final globalPos = box.localToGlobal(Offset(x, y));

    final dateLabel = '${date.month}/${date.day}';

    String text;
    Color textColor;
    if (v == null) {
      text = '$dateLabel · not logged';
      textColor = Colors.grey[600]!;
    } else {
      final progress = goal > 0 ? v / goal : 0.0;
      final color =
          TrackerCard.getProgressColor(progress, category, goalValue: goal);
      final status = _weeklyStatusLabel(color);
      text = '${_formatNum(v)}/${_formatNum(goal)} · $status';
      textColor = color;
    }

    _weeklyBarHoverOverlay?.remove();
    _weeklyBarHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPos.dx - 70,
        top: globalPos.dy - 40,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_weeklyBarHoverOverlay!);

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _removeWeeklyBarHoverOverlay();
    });
  }

  void _removeWeeklyBarHoverOverlay() {
    _weeklyBarHoverOverlay?.remove();
    _weeklyBarHoverOverlay = null;
  }

  /// Dynamic Y-axis ticks, positioned by actual value (not evenly spaced by
  /// index) so they land at the same pixel the painter draws them at — and
  /// the goal/limit itself is always one of the labels, so the dashed
  /// reference line never falls between two unrelated "nice" numbers.
  Widget _buildDynamicYAxisLabels(double chartMax, double goal) {
    final step = _niceAxisStep(chartMax);
    final ticks = <double>[];
    for (double t = 0; t <= chartMax + 0.0001; t += step) {
      ticks.add(t);
    }
    final minGap = chartMax * 0.12;
    ticks.removeWhere((t) => t != 0 && (t - goal).abs() < minGap);
    ticks.add(goal);
    ticks.sort();

    const chartPadding = 4.0;
    const chartHeight = 200.0;
    const chartRectBottom = chartHeight - chartPadding;
    const chartRectHeight = chartHeight - chartPadding * 2;
    double valueToY(double v) =>
        chartRectBottom - (chartMax > 0 ? v / chartMax : 0.0) * chartRectHeight;

    const fontSize = 10.0;
    // A fixed label-box height, centered on the tick's Y — more reliable
    // than estimating an offset from fontSize, since actual rendered line
    // height (with bold weight/leading) is taller than the raw font size.
    const labelBoxHeight = 16.0;

    return SizedBox(
      width: 28,
      height: chartHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: ticks.map((t) {
          return Positioned(
            right: 0,
            top: valueToY(t) - labelBoxHeight / 2,
            height: labelBoxHeight,
            child: Center(
              child: Text(
                t == t.roundToDouble()
                    ? t.toStringAsFixed(0)
                    : t.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyWeeklyGraphCard(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
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
              height: 200,
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
        case 'veggies':
          return _buildVeggiesWeeklyGraphCard();
        case 'fruits':
          return _buildFruitsWeeklyGraphCard();
        case 'protein':
          return _buildProteinWeeklyGraphCard();
        case 'grains':
          return _buildGrainsWeeklyGraphCard();
        case 'dairy':
          return _buildDairyWeeklyGraphCard();
        case 'fatsOils':
          return _buildFatsOilsWeeklyGraphCard();
        case 'water':
          return _buildWaterWeeklyGraphCard();
        case 'sodium':
          return _buildSodiumWeeklyGraphCard();
        default:
          return const SizedBox.shrink();
      }
    }).toList();
    final showPrev = _weeklyGraphPageIndex > 0;
    final showNext = _weeklyGraphPageIndex < _weeklyGraphCount - 1;

    return MouseRegion(
      onEnter: (_) {
        _carouselArrowsHideTimer?.cancel();
        if (!_showCarouselArrows && mounted) {
          setState(() => _showCarouselArrows = true);
        }
      },
      onExit: (_) {
        _carouselArrowsHideTimer?.cancel();
        if (_showCarouselArrows && mounted) {
          setState(() => _showCarouselArrows = false);
        }
      },
      child: GestureDetector(
        onTapDown: (_) => _showCarouselArrowsTemporarily(),
        child: SizedBox(
          height: 330,
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
                      color: Colors.white,
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
                          child: Icon(Icons.chevron_left,
                              color: Color(0xFFFF6A00), size: 28),
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
                      color: Colors.white,
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
                          child: Icon(Icons.chevron_right,
                              color: Color(0xFFFF6A00), size: 28),
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

  Widget _buildVeggiesWeeklyGraphCard() {
    final goal = _veggiesGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Veggies');
    return _buildWeeklyGraphCards(
      title: 'Veggies',
      subtitle: 'Servings per day',
      values: _veggiesWeekServings,
      goal: goal,
      category: TrackerCategory.veggies,
    );
  }

  Widget _buildFruitsWeeklyGraphCard() {
    final goal = _fruitsGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Fruits');
    return _buildWeeklyGraphCards(
      title: 'Fruits',
      subtitle: 'Servings per day',
      values: _fruitsWeekServings,
      goal: goal,
      category: TrackerCategory.fruits,
    );
  }

  Widget _buildWaterWeeklyGraphCard() {
    final goal = _waterGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Water');
    return _buildWeeklyGraphCards(
      title: 'Water',
      subtitle: 'Cups per day',
      values: _waterWeekServings,
      goal: goal,
      category: TrackerCategory.water,
    );
  }

  Widget _buildProteinWeeklyGraphCard() {
    final goal = _proteinGoalValue;
    if (goal == null || goal <= 0) {
      return _buildEmptyWeeklyGraphCard('Protein');
    }
    return _buildWeeklyGraphCards(
      title: 'Protein',
      subtitle: 'oz per day',
      values: _proteinWeekServings,
      goal: goal,
      category: TrackerCategory.protein,
    );
  }

  Widget _buildGrainsWeeklyGraphCard() {
    final goal = _grainsGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Grains');
    return _buildWeeklyGraphCards(
      title: 'Grains',
      subtitle: 'oz per day',
      values: _grainsWeekServings,
      goal: goal,
      category: TrackerCategory.grains,
    );
  }

  Widget _buildDairyWeeklyGraphCard() {
    final goal = _dairyGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Dairy');
    return _buildWeeklyGraphCards(
      title: 'Dairy',
      subtitle: 'Cups per day',
      values: _dairyWeekServings,
      goal: goal,
      category: TrackerCategory.dairy,
    );
  }

  Widget _buildFatsOilsWeeklyGraphCard() {
    final goal = _fatsOilsGoalValue;
    if (goal == null || goal <= 0) {
      return _buildEmptyWeeklyGraphCard('Fats/Oils');
    }
    return _buildWeeklyGraphCards(
      title: 'Fats/Oils',
      subtitle: 'Servings per day',
      values: _fatsOilsWeekServings,
      goal: goal,
      category: TrackerCategory.fatsOils,
    );
  }

  Widget _buildSodiumWeeklyGraphCard() {
    final goal = _sodiumGoalValue;
    if (goal == null || goal <= 0) return _buildEmptyWeeklyGraphCard('Sodium');
    return _buildWeeklyGraphCards(
      title: 'Sodium',
      subtitle: 'mg per day',
      values: _sodiumWeekServings,
      goal: goal,
      category: TrackerCategory.sodium,
    );
  }

  static const double _lineChartHeight = 200.0;

  /// One card per category with a line/bar chart-type toggle in the header.
  /// Both chart bodies read the exact same `values`/`goal`/`category` and
  /// share date range, tooltip and status-color logic — the toggle only
  /// swaps which painter is shown, it never touches the underlying data.
  Widget _buildWeeklyGraphCards({
    required String title,
    required String subtitle,
    required List<double?> values,
    required double goal,
    required TrackerCategory category,
  }) {
    final isLowerBetter = category == TrackerCategory.sodium;
    final goalText =
        '${isLowerBetter ? "Limit" : "Goal"} ${_formatNum(goal)}${isLowerBetter ? " mg" : ""}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$subtitle · $goalText',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _buildChartTypeToggle(),
              ],
            ),
            const SizedBox(height: 12),
            _weeklyChartType == _WeeklyChartType.line
                ? _buildLineChartBody(
                    values: values, goal: goal, category: category)
                : _buildBarChartBody(
                    values: values, goal: goal, category: category),
          ],
        ),
      ),
    );
  }

  /// Small segmented control for switching chart type: line and bar icons
  /// side by side, active one filled solid in the app's accent orange (same
  /// color as the carousel arrows).
  Widget _buildChartTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChartTypeToggleButton(Icons.show_chart, _WeeklyChartType.line),
          _buildChartTypeToggleButton(Icons.bar_chart, _WeeklyChartType.bar),
        ],
      ),
    );
  }

  Widget _buildChartTypeToggleButton(IconData icon, _WeeklyChartType type) {
    final selected = _weeklyChartType == type;
    return GestureDetector(
      onTap: () {
        if (_weeklyChartType != type) {
          setState(() => _weeklyChartType = type);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6A00) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 15,
          color: selected ? Colors.white : Colors.grey[500],
        ),
      ),
    );
  }

  /// Date row shared by the line-chart and bar-chart cards: `count` equal
  /// slots starting from `start`, each centered under its chart point.
  Widget _buildWeeklyDateLabelsRow(DateTime start, int count) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = (constraints.maxWidth - 8) * 0.98;
        final slotWidth = innerWidth / count;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SizedBox(
            width: innerWidth,
            child: Row(
              children: List.generate(count, (i) {
                final d = start.add(Duration(days: i));
                return SizedBox(
                  width: slotWidth,
                  child: Text(
                    '${d.month}/${d.day}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  /// Line-chart body: dynamic Y-axis shared with the bar chart, a smoothed
  /// line through the week's values with each point colored by status, and
  /// gaps (not zeros) for days with no snapshot.
  Widget _buildLineChartBody({
    required List<double?> values,
    required double goal,
    required TrackerCategory category,
  }) {
    final start = _weeklyGraphStart;
    final chartMax = _weeklyChartMax(values, goal);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDynamicYAxisLabels(chartMax, goal),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _lineChartHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    const h = _lineChartHeight;
                    final chartInnerWidth = (w - 8) * 0.98;
                    final labelCenterXs = _MealGoalsHistoryPageState
                        ._computeDateLabelCenterXs(
                            values.length, chartInnerWidth);
                    return GestureDetector(
                      onTapUp: (details) {
                        final index = _getWeeklyBarIndexAt(
                            details.localPosition, labelCenterXs);
                        if (index != null && context.mounted) {
                          _showWeeklyBarTooltip(
                            context,
                            index,
                            Size(w, h),
                            labelCenterXs,
                            values,
                            goal,
                            category,
                            start,
                          );
                        }
                      },
                      child: CustomPaint(
                        painter: _WeeklyLineChartPainter(
                          values: values,
                          goal: goal,
                          category: category,
                          labelCenterXs: labelCenterXs,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _buildWeeklyDateLabelsRow(start, values.length),
            ],
          ),
        ),
      ],
    );
  }

  /// Shared bar-chart body for every category — status color comes from
  /// TrackerCard.getProgressColor (same rule as the Home tracker cards), the
  /// Y-axis is a dynamic "nice" scale and there is exactly one reference
  /// line (Goal, or Limit for sodium where lower is better).
  Widget _buildBarChartBody({
    required List<double?> values,
    required double goal,
    required TrackerCategory category,
  }) {
    final chartMax = _weeklyChartMax(values, goal);
    final start = _weeklyGraphStart;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDynamicYAxisLabels(chartMax, goal),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 200,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    const h = 200.0;
                    final chartInnerWidth = (w - 8) * 0.98;
                    final labelCenterXs = _MealGoalsHistoryPageState
                        ._computeDateLabelCenterXs(
                            values.length, chartInnerWidth);
                    return GestureDetector(
                      onTapUp: (details) {
                        final index = _getWeeklyBarIndexAt(
                            details.localPosition, labelCenterXs);
                        if (index != null && context.mounted) {
                          _showWeeklyBarTooltip(
                            context,
                            index,
                            Size(w, h),
                            labelCenterXs,
                            values,
                            goal,
                            category,
                            start,
                          );
                        }
                      },
                      child: CustomPaint(
                        painter: _WeeklyBarChartPainter(
                          values: values,
                          goal: goal,
                          category: category,
                          labelCenterXs: labelCenterXs,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _buildWeeklyDateLabelsRow(start, values.length),
            ],
          ),
        ),
      ],
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
    if (key == 'water' || key == 'veggies' || key == 'fruits' || key == 'dairy') {
      return 'Cups';
    }
    if (key == 'protein' || key == 'grains') return 'oz';
    if (key == 'fatsOils') return 'Servings';
    return '';
  }

  String _formatNum(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    if ((v * 10) == (v * 10).truncateToDouble()) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  /// Center X of each date label across `count` equal-width slots, matching
  /// the slot centers used by _buildWeeklyDateLabelsRow.
  static List<double> _computeDateLabelCenterXs(int count, double innerWidth) {
    if (count <= 0) return [];
    final slotWidth = innerWidth / count;
    return List.generate(count, (i) => slotWidth * (i + 0.5));
  }
}

/// Bar-chart painter for the Weekly Summary — one rounded bar per day,
/// colored by the same status rule as the Home tracker cards
/// (TrackerCard.getProgressColor), a gap (no bar) for days with no data, and
/// a single dashed reference line at the goal/limit value.
class _WeeklyBarChartPainter extends CustomPainter {
  final List<double?> values;
  final double goal;
  final TrackerCategory category;
  final List<double>? labelCenterXs;

  _WeeklyBarChartPainter({
    required this.values,
    required this.goal,
    required this.category,
    this.labelCenterXs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (goal <= 0 || values.isEmpty) return;

    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      size.width - chartPadding * 2,
      size.height - chartPadding * 2,
    );
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;
    final n = values.length;

    double maxLogged = 0.0;
    for (final v in values) {
      if (v != null && v > maxLogged) maxLogged = v;
    }
    final chartMax = (goal > maxLogged ? goal : maxLogged) * 1.15;

    double valueToY(double v) {
      final ratio = chartMax > 0 ? v.clamp(0.0, chartMax) / chartMax : 0.0;
      return chartRect.bottom - ratio * chartRect.height;
    }

    // X-axis.
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    // Single dashed reference line at the goal/limit value.
    final goalY = valueToY(goal);
    final refPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dashWidth = 4.0, dashSpace = 3.0;
    double dashX = chartRect.left;
    while (dashX < chartRect.right) {
      final endX = (dashX + dashWidth).clamp(chartRect.left, chartRect.right);
      canvas.drawLine(Offset(dashX, goalY), Offset(endX, goalY), refPaint);
      dashX += dashWidth + dashSpace;
    }

    const barWidth = 16.0;
    for (int i = 0; i < n; i++) {
      final v = values[i];
      final x = labelCenterXs != null && i < labelCenterXs!.length
          ? innerLeft + labelCenterXs![i]
          : innerLeft + (innerWidth / n) * (i + 0.5);

      if (v == null) {
        // No data logged that day: no bar, no tick — just the gap.
        continue;
      }

      final progress = goal > 0 ? v / goal : 0.0;
      final color =
          TrackerCard.getProgressColor(progress, category, goalValue: goal);
      var top = valueToY(v);
      // An explicit 0 still needs to be visibly different from "no bar".
      if (top > chartRect.bottom - 3) top = chartRect.bottom - 3;
      final rect = Rect.fromLTRB(
          x - barWidth / 2, top, x + barWidth / 2, chartRect.bottom);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarChartPainter oldDelegate) {
    if (oldDelegate.goal != goal || oldDelegate.category != category) {
      return true;
    }
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

/// Line-chart painter for the Weekly Summary — a smoothed solid line through
/// the week's values, with each point colored by the same status rule as
/// the bar chart (TrackerCard.getProgressColor) and a single dashed
/// reference line at the goal/limit value. A null value (no snapshot for
/// that day) breaks the line into a gap rather than being drawn as zero.
class _WeeklyLineChartPainter extends CustomPainter {
  final List<double?> values;
  final double goal;
  final TrackerCategory category;

  /// Center X of each date label (0..innerWidth); when provided, dots align with dates.
  final List<double>? labelCenterXs;

  _WeeklyLineChartPainter({
    required this.values,
    required this.goal,
    required this.category,
    this.labelCenterXs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (goal <= 0 || values.isEmpty) return;

    const chartPadding = 4.0;
    final chartRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      size.width - chartPadding * 2,
      size.height - chartPadding * 2,
    );

    // Dynamic scale — same rule as the bar chart, so a value that exceeds
    // goal draws above the goal line instead of being capped at it.
    double maxLogged = 0.0;
    for (final v in values) {
      if (v != null && v > maxLogged) maxLogged = v;
    }
    final chartMax = (goal > maxLogged ? goal : maxLogged) * 1.15;

    // Use a slightly narrower inner width for points/curve so the last point
    // does not sit directly on the Y-axis.
    final innerWidth = chartRect.width * 0.98;
    final innerLeft = chartRect.left;

    double valueToY(double v) {
      final ratio = chartMax > 0 ? v.clamp(0.0, chartMax) / chartMax : 0.0;
      return chartRect.bottom - ratio * chartRect.height;
    }

    // X-axis (bottom) — no vertical Y-axis line, matching the bar chart;
    // the axis numbers themselves mark the scale.
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    // Single dashed reference line at the goal/limit value — same style as
    // the bar chart's reference line.
    final goalY = valueToY(goal);
    final refPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dashWidth = 4.0, dashSpace = 3.0;
    double dashX = chartRect.left;
    while (dashX < chartRect.right) {
      final endX = (dashX + dashWidth).clamp(chartRect.left, chartRect.right);
      canvas.drawLine(Offset(dashX, goalY), Offset(endX, goalY), refPaint);
      dashX += dashWidth + dashSpace;
    }

    // Build points for all days with data — index preserved, gaps (null)
    // simply have no entry, so the line breaks around them instead of
    // dipping to a false zero.
    final n = values.length;
    final points = <int, Offset>{};
    for (int i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      final x = labelCenterXs != null && i < labelCenterXs!.length
          ? innerLeft + labelCenterXs![i]
          : innerLeft + (innerWidth / n) * (i + 0.5);
      points[i] = Offset(x, valueToY(v));
    }
    if (points.isEmpty) return;

    // Group consecutive indices (no gap between them) into runs and draw
    // each run as its own smoothed dashed path.
    final sortedIndices = points.keys.toList()..sort();
    final runs = <List<int>>[];
    for (final i in sortedIndices) {
      if (runs.isNotEmpty && runs.last.last == i - 1) {
        runs.last.add(i);
      } else {
        runs.add([i]);
      }
    }

    final linePaint = Paint()
      ..color = Colors.grey.shade500 // neutral structure — status lives on the dots
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Dot color follows the same status rule the bar chart uses — the
    // connecting line stays neutral grey, it's just structure. A dark
    // outline keeps lighter fills (yellow especially) legible on white.
    Color dotColorFor(int index) {
      final v = values[index]!;
      final progress = goal > 0 ? v / goal : 0.0;
      return TrackerCard.getProgressColor(progress, category, goalValue: goal);
    }

    void drawDot(Offset p, Color color) {
      canvas.drawCircle(p, 4.0, Paint()..color = color);
      canvas.drawCircle(
        p,
        4.0,
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    for (final run in runs) {
      final runPoints = run.map((i) => points[i]!).toList();
      if (runPoints.length < 2) {
        // Single isolated day of data: draw just the dot.
        drawDot(runPoints[0], dotColorFor(run[0]));
        continue;
      }

      final path = Path();
      path.moveTo(runPoints[0].dx, runPoints[0].dy);
      for (int i = 0; i < runPoints.length - 1; i++) {
        final p1 = runPoints[i];
        final p2 = runPoints[i + 1];
        final v1 = values[run[i]]!;
        final v2 = values[run[i + 1]]!;
        // Straight line when both points have the same value (e.g. both zero)
        if ((v1 - v2).abs() < 0.001) {
          path.lineTo(p2.dx, p2.dy);
        } else {
          final p0 = i > 0 ? runPoints[i - 1] : runPoints[i];
          final p3 =
              i + 2 < runPoints.length ? runPoints[i + 2] : runPoints[i + 1];
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

      canvas.drawPath(path, linePaint);

      for (int i = 0; i < runPoints.length; i++) {
        drawDot(runPoints[i], dotColorFor(run[i]));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyLineChartPainter oldDelegate) {
    if (oldDelegate.goal != goal) return true;
    if (oldDelegate.category != category) return true;
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
