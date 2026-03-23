import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal for user to enter how many servings they consumed when cooking a recipe,
/// or when logging from a prepared (leftover) recipe.
/// Returns the value via Navigator.pop when Log is pressed, or null when Cancel/close.
class ServingsConsumedModal extends StatefulWidget {
  final int recipeServings;
  final double? maxServings;
  final String? subtitle;

  const ServingsConsumedModal({
    super.key,
    required this.recipeServings,
    this.maxServings,
    this.subtitle,
  });

  @override
  State<ServingsConsumedModal> createState() => _ServingsConsumedModalState();
}

class _ServingsConsumedModalState extends State<ServingsConsumedModal> {
  late TextEditingController _valueController;
  late double _currentValue;
  bool _isUpdating = false;
  String? _error;

  static const double _step = 0.25;
  static const double _min = 0.25;

  @override
  void initState() {
    super.initState();
    _currentValue = 1.0.clamp(_min, _max);
    _valueController = TextEditingController(text: _formatValue(_currentValue));
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  double get _max => widget.maxServings ?? widget.recipeServings.toDouble();

  String get _subtitle =>
      widget.subtitle ?? 'Recipe makes ${widget.recipeServings} servings';

  List<double> get _presets {
    final candidates = [0.5, 1.0, 1.5, 2.0];
    return candidates.where((v) => v >= _min && v <= _max).toSet().toList()
      ..sort();
  }

  void _incrementValue() {
    setState(() {
      _currentValue = (_currentValue + _step).clamp(_min, _max);
      _valueController.text = _formatValue(_currentValue);
      _error = null;
    });
  }

  void _decrementValue() {
    if (_currentValue > _min) {
      setState(() {
        _currentValue = (_currentValue - _step).clamp(_min, _max);
        _valueController.text = _formatValue(_currentValue);
        _error = null;
      });
    }
  }

  void _setPreset(double value) {
    setState(() {
      _currentValue = value;
      _valueController.text = _formatValue(_currentValue);
      _error = null;
    });
  }

  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    } else if ((value * 100) == (value * 100).truncateToDouble()) {
      return value.toStringAsFixed(2);
    } else {
      return value.toStringAsFixed(2);
    }
  }

  Future<void> _handleLog() async {
    if (_isUpdating) return;

    if (_currentValue < _min) {
      setState(() {
        _error = 'Minimum is $_min servings';
      });
      return;
    }
    if (_currentValue > _max) {
      setState(() {
        _error = 'Maximum is $_max servings';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
      _error = null;
    });

    try {
      if (mounted) {
        Navigator.of(context).pop(_currentValue);
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

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFFFF6A00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Log serving',
                    style: TextStyle(
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
            const Text(
              'How many servings did you have?',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'BricolageGrotesque',
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C2C2C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'BricolageGrotesque',
                color: Color(0xFF8E8E93),
              ),
              textAlign: TextAlign.center,
            ),
            if (_presets.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _presets.map((v) {
                  final isSelected = (_currentValue - v).abs() < 0.01;
                  return GestureDetector(
                    onTap: () => _setPreset(v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF6A00).withValues(alpha: 0.2)
                            : const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF6A00)
                              : const Color(0xFFE5E5EA),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        v == v.truncateToDouble()
                            ? v.toInt().toString()
                            : v.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFFFF6A00)
                              : const Color(0xFF2C2C2C),
                          fontFamily: 'BricolageGrotesque',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
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
                        color: _currentValue > _min
                            ? const Color(0xFFFF5275).withValues(alpha: 0.1)
                            : const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 20,
                        color: _currentValue > _min
                            ? const Color(0xFFFF5275)
                            : const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 100,
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
                              final parsed = double.tryParse(value);
                              if (parsed != null) {
                                setState(() {
                                  _currentValue = parsed.clamp(_min, _max);
                                  _error = null;
                                });
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'servings',
                          style: TextStyle(
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
