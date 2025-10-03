import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/tracker_goal.dart';

class ManualTrackerLoggingModal extends StatefulWidget {
  final TrackerGoal tracker;
  final Function(double) onLog;

  const ManualTrackerLoggingModal({
    Key? key,
    required this.tracker,
    required this.onLog,
  }) : super(key: key);

  @override
  State<ManualTrackerLoggingModal> createState() =>
      _ManualTrackerLoggingModalState();
}

class _ManualTrackerLoggingModalState extends State<ManualTrackerLoggingModal> {
  late TextEditingController _valueController;
  late double _currentValue;
  bool _isUpdating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentValue = 0.0;
    _valueController = TextEditingController(text: _currentValue.toString());
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _incrementValue() {
    setState(() {
      _currentValue += _getIncrementStep();
      _valueController.text = _formatValue(_currentValue);
    });
  }

  void _decrementValue() {
    if (_currentValue > 0) {
      setState(() {
        _currentValue =
            (_currentValue - _getIncrementStep()).clamp(0, double.infinity);
        _valueController.text = _formatValue(_currentValue);
      });
    }
  }

  double _getIncrementStep() {
    switch (widget.tracker.category) {
      case TrackerCategory.sodium:
        return 100.0; // 100mg increments
      case TrackerCategory.fatsOils:
        return 0.5; // 0.5 tbsp increments
      case TrackerCategory.water:
        return 0.5; // 0.5 cup increments
      case TrackerCategory.other:
        return 1.0; // 1 unit increments
      default:
        return 0.5;
    }
  }

  String _getCategorySpecificHint() {
    switch (widget.tracker.category) {
      case TrackerCategory.sodium:
        return 'Enter sodium servings (e.g., 2 servings)';
      case TrackerCategory.fatsOils:
        return 'Enter fat/oil servings (e.g., 2 servings)';
      case TrackerCategory.water:
        return 'Enter water servings (e.g., 2 servings)';
      case TrackerCategory.other:
        return 'Enter servings';
      default:
        return 'Enter servings';
    }
  }

  String _getCategorySpecificExamples() {
    switch (widget.tracker.category) {
      case TrackerCategory.sodium:
        return 'Examples: 1 tsp salt ≈ 1 serving, 1 slice bread ≈ 0.1 serving';
      case TrackerCategory.fatsOils:
        return 'Examples: 1 tbsp olive oil ≈ 1 serving, 1 pat butter ≈ 1 serving';
      case TrackerCategory.water:
        return 'Examples: 1 glass ≈ 1 serving, 1 bottle ≈ 2 servings';
      case TrackerCategory.other:
        return 'Enter the servings you consumed';
      default:
        return '';
    }
  }

  Future<void> _handleLog() async {
    if (_isUpdating) return;

    if (_currentValue <= 0) {
      setState(() {
        _error = 'Please enter a value greater than 0';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
      _error = null;
    });

    try {
      await widget.onLog(_currentValue);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  /// Helper method to format values with sensible decimal places
  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      // Whole number
      return value.toStringAsFixed(0);
    } else if ((value * 10) == (value * 10).truncateToDouble()) {
      // One decimal place (like 1.5)
      return value.toStringAsFixed(1);
    } else {
      // Two decimal places max (like 1.25)
      return value.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconPath = getTrackerIconAsset(widget.tracker.category);
    final isSvg = iconPath.endsWith('.svg');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: isSvg
                      ? SvgPicture.asset(
                          iconPath,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          iconPath,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Log ${widget.tracker.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'BricolageGrotesque',
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF2C2C2C),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Instructions
            Text(
              _getCategorySpecificHint(),
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'BricolageGrotesque',
                color: Color(0xFF8E8E93),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getCategorySpecificExamples(),
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'BricolageGrotesque',
                color: Color(0xFF8E8E93),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5275).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF5275),
                    fontFamily: 'BricolageGrotesque',
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Input section
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isUpdating ? null : _decrementValue,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _currentValue > 0
                            ? const Color(0xFFFF5275).withValues(alpha: 0.1)
                            : const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: _currentValue > 0
                            ? const Color(0xFFFF5275)
                            : const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        TextField(
                          controller: _valueController,
                          enabled: !_isUpdating,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'BricolageGrotesque',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C2C2C),
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE5E5EA)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE5E5EA)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFFFF6A00), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*$')),
                          ],
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                _currentValue = double.parse(value);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.tracker.unitString,
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontFamily: 'BricolageGrotesque',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _isUpdating ? null : _incrementValue,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6A00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xFFFF6A00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isUpdating ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isUpdating ? null : _handleLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Log',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'BricolageGrotesque',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
