import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/utils/typography.dart';

class AppFormField extends StatelessWidget {
  final String? label;
  final String hintText;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Function(String)? onFieldSubmitted;

  const AppFormField({
    super.key,
    this.label,
    required this.hintText,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.bg_16_m,
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bg_14_r.copyWith(
              color: const Color(0xFF90909A),
            ),
            filled: true,
            fillColor: const Color(0xFFF7F7F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class AppRadioGroup<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<Map<T, String>> options;
  final ValueChanged<T?>? onChanged;

  const AppRadioGroup({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bg_16_m,
        ),
        const SizedBox(height: 16),
        ...options.map((option) {
          final optionValue = option.keys.first;
          final optionLabel = option.values.first;
          return Container(
            margin: const EdgeInsets.only(bottom: 0),
            child: RadioListTile<T>(
              title: Text(
                optionLabel,
                style: AppTypography.bg_14_r.copyWith(
                  color: const Color(0xFF2C2C2C),
                ),
              ),
              value: optionValue,
              groupValue: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFFF6A00),
              contentPadding: EdgeInsets.zero,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              dense: true,
            ),
          );
        }).toList(),
      ],
    );
  }
}

class AppCheckboxGroup extends StatelessWidget {
  final String label;
  final List<String> selectedValues;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  const AppCheckboxGroup({
    super.key,
    required this.label,
    required this.selectedValues,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bg_16_m,
        ),
        const SizedBox(height: 16),
        ...options.map((option) {
          final isSelected = selectedValues.contains(option);
          return InkWell(
            onTap: () {
              final newValues = List<String>.from(selectedValues);
              if (isSelected) {
                newValues.remove(option);
              } else {
                newValues.add(option);
              }
              onChanged(newValues);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFFFF6A00) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: const Color(0xFFE7E9EC),
                              width: 1,
                            ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option,
                      style: AppTypography.bg_14_r.copyWith(
                        color: const Color(0xFF2C2C2C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class AppChipGroup extends StatelessWidget {
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const AppChipGroup({
    super.key,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return Chip(
          label: Text(value),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () {
            final newValues = List<String>.from(values)..remove(value);
            onChanged(newValues);
          },
          backgroundColor: const Color(0xFFFFEFE7),
          labelStyle: const TextStyle(color: Color(0xFFFF6A00)),
          deleteIconColor: const Color(0xFFFF6A00),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        );
      }).toList(),
    );
  }
}

class AppDropdownField extends StatefulWidget {
  final String? label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final String hintText;
  final bool showSearchBar;
  final bool useBottomSheet;
  final bool multiSelect;
  final List<String>? selectedValues;
  final ValueChanged<List<String>>? onChangedMulti;

  const AppDropdownField({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.hintText,
    this.showSearchBar = false,
    this.useBottomSheet = true,
    this.multiSelect = false,
    this.selectedValues,
    this.onChangedMulti,
  });

  @override
  State<AppDropdownField> createState() => _AppDropdownFieldState();
}

class _AppDropdownFieldState extends State<AppDropdownField> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredOptions = [];
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Avoid setState in dispose; just tear down overlay and controllers safely
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filterOptions(String query) {
    setState(() {
      _filteredOptions = widget.options
          .where((option) => option.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(
            widget.label!,
            style: AppTypography.bg_16_m,
          ),
          const SizedBox(height: 8),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            onTap: () {
              if (widget.useBottomSheet) {
                _openBottomSheet();
              } else {
                if (_isExpanded) {
                  _removeOverlay();
                } else {
                  _showOverlay();
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.value ?? widget.hintText,
                      style: widget.value != null
                          ? AppTypography.bg_14_r
                          : AppTypography.bg_14_r.copyWith(
                              color: const Color(0xFF90909A),
                            ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF90909A),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openBottomSheet() async {
    List<String> localFiltered = List<String>.from(widget.options);
    final controller = TextEditingController();
    final Set<String> tempSelected =
        Set<String>.from(widget.selectedValues ?? const <String>[]);

    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Container(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.label ?? 'Select',
                        style: AppTypography.bg_16_m,
                      ),
                      TextButton(
                        onPressed: () {
                          if (widget.multiSelect) {
                            Navigator.pop(sheetContext, tempSelected.toList());
                          } else {
                            Navigator.pop(sheetContext);
                          }
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (widget.showSearchBar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Search here',
                        hintStyle: AppTypography.bg_14_r
                            .copyWith(color: const Color(0xFF90909A)),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF90909A)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F8),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (q) {
                        localFiltered = widget.options
                            .where((o) =>
                                o.toLowerCase().contains(q.toLowerCase()))
                            .toList();
                        setModalState(() {});
                      },
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: localFiltered.length,
                    itemBuilder: (itemContext, index) {
                      final option = localFiltered[index];
                      if (widget.multiSelect) {
                        final isChecked = tempSelected.contains(option);
                        return CheckboxListTile(
                          title: Text(option, style: AppTypography.bg_14_r),
                          value: isChecked,
                          onChanged: (v) {
                            if (v == true) {
                              tempSelected.add(option);
                            } else {
                              tempSelected.remove(option);
                            }
                            setModalState(() {});
                          },
                          activeColor: const Color(0xFFFF6A00),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      } else {
                        return ListTile(
                          title: Text(option, style: AppTypography.bg_14_r),
                          onTap: () => Navigator.pop(sheetContext, option),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!mounted) return;
    if (result != null) {
      if (widget.multiSelect) {
        final List<String> selectedList = List<String>.from(result);
        widget.onChangedMulti?.call(selectedList);
      } else {
        widget.onChanged?.call(result as String);
      }
      setState(() {});
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isExpanded = true;
    });
    if (widget.showSearchBar) {
      // Delay focus to ensure overlay is built
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _isExpanded = false;
      _searchController.clear();
      _filteredOptions = widget.options;
    });
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap-away barrier
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
              child: const SizedBox.shrink(),
            ),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showSearchBar)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Search here',
                              hintStyle: AppTypography.bg_14_r.copyWith(
                                color: const Color(0xFF90909A),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF90909A),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7F7F8),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onChanged: _filterOptions,
                          ),
                        ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _filteredOptions.length,
                          itemBuilder: (context, index) {
                            final option = _filteredOptions[index];
                            return InkWell(
                              onTap: () {
                                widget.onChanged?.call(option);
                                _removeOverlay();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  option,
                                  style: AppTypography.bg_14_r,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeightDropdownField extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final String hintText;

  const HeightDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.hintText,
  });

  @override
  State<HeightDropdownField> createState() => _HeightDropdownFieldState();
}

class _HeightDropdownFieldState extends State<HeightDropdownField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isExpanded = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isExpanded = false;
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isExpanded = true;
    });
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: widget.options.length,
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  return InkWell(
                    onTap: () {
                      widget.onChanged?.call(option);
                      _removeOverlay();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        option,
                        style: AppTypography.bg_14_r,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (_isExpanded) {
            _removeOverlay();
          } else {
            _showOverlay();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value ?? widget.hintText,
                  style: widget.value != null
                      ? AppTypography.bg_14_r
                      : AppTypography.bg_14_r.copyWith(
                          color: const Color(0xFF90909A),
                        ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF90909A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSearchAnchor extends StatelessWidget {
  final String hintText;
  final Widget? leading;
  final List<Widget>? trailing;
  final FutureOr<Iterable<Widget>> Function(BuildContext, SearchController)
      suggestionsBuilder;
  final SearchController? controller;

  const AppSearchAnchor({
    super.key,
    required this.hintText,
    required this.suggestionsBuilder,
    this.leading,
    this.trailing,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: controller,
      viewBackgroundColor: Colors.white,
      builder: (BuildContext context, SearchController searchController) {
        return SearchBar(
          controller: searchController,
          onTap: () => searchController.openView(),
          onChanged: (query) => searchController.openView(),
          hintText: hintText,
          leading: leading ?? Icon(Icons.search, color: Colors.grey[400]),
          trailing: trailing,
          backgroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.all(0.0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          hintStyle: WidgetStateProperty.all(
            TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
          ),
        );
      },
      suggestionsBuilder: suggestionsBuilder,
    );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  const AppSearchField({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[400],
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15, // Adjusted for vertical centering
          ),
        ),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }
}
