import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _primaryOrange = Color(0xFFFF6A00);

/// Clamps picker dialog [TextScaler] to 1.0–1.25×.
TextScaler _pickerTextScaler(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1.0);
  return TextScaler.linear(scale.clamp(1.0, 1.25));
}

ThemeData _signupDatePickerTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: _primaryOrange,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF2C2C2C),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryOrange,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Signup-themed date dialog; [CalendarDatePicker] height follows month row count
/// instead of [DatePickerDialog]'s fixed six-row grid.
Future<DateTime?> showSignupDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return MediaQuery(
        data: MediaQuery.of(dialogContext).copyWith(
          textScaler: _pickerTextScaler(dialogContext),
        ),
        child: Theme(
          data: _signupDatePickerTheme(dialogContext),
          child: _SignupDatePickerDialog(
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            initialCalendarMode: initialDatePickerMode,
          ),
        ),
      );
    },
  );
}

class _SignupDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DatePickerMode initialCalendarMode;

  const _SignupDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.initialCalendarMode,
  });

  @override
  State<_SignupDatePickerDialog> createState() =>
      _SignupDatePickerDialogState();
}

class _SignupDatePickerDialogState extends State<_SignupDatePickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final headerDate = DateFormat('EEE, MMM d').format(_selectedDate);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select date of birth',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      headerDate,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                currentDate: DateTime.now(),
                initialCalendarMode: widget.initialCalendarMode,
                onDateChanged: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _selectedDate),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
