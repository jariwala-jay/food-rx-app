import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/core/models/excluded_ingredient.dart';
import 'package:flutter_app/features/pantry/repositories/ingredient_repository.dart';
import 'package:flutter_app/features/pantry/repositories/spoonacular_ingredient_repository.dart';

/// Confirms clearing every additional ingredient before it happens, so
/// "Clear All" can't silently wipe a user's saved allergens.
Future<bool> _confirmClearAllIngredients(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Remove all additional ingredients?',
              style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "This will remove all additional ingredients you've selected "
              'under Other.',
              style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 15,
                color: Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5F5F6E),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

class AdditionalFoodsToAvoidField extends StatelessWidget {
  final List<ExcludedIngredient> selected;
  final ValueChanged<List<ExcludedIngredient>> onChanged;

  const AdditionalFoodsToAvoidField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static Future<List<ExcludedIngredient>?> showPicker(
    BuildContext context, {
    required List<ExcludedIngredient> initialSelection,
  }) {
    return showModalBottomSheet<List<ExcludedIngredient>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AdditionalFoodsPickerSheet(
        initialSelection: initialSelection,
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showPicker(
      context,
      initialSelection: selected,
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Foods to Avoid',
          style: TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE7E9EC)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Search ingredients or add your own',
                    style: TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      color: Color(0xFF777777),
                    ),
                  ),
                ),
                Icon(Icons.search, color: Color(0xFF777777)),
              ],
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selected
                .map(
                  (ingredient) => InputChip(
                    label: Text(ingredient.displayName),
                    labelStyle: const TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      color: Color(0xFFFF6A00),
                    ),
                    backgroundColor: const Color(0xFFFFEFE7),
                    deleteIconColor: const Color(0xFFFF6A00),
                    onDeleted: () => onChanged(
                      selected.where((item) => item != ingredient).toList(),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'These foods will be excluded from your recipe recommendations.',
          style: TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 12,
            color: Color(0xFF777777),
          ),
        ),
      ],
    );
  }
}

class _AdditionalFoodsPickerSheet extends StatefulWidget {
  final List<ExcludedIngredient> initialSelection;

  const _AdditionalFoodsPickerSheet({
    required this.initialSelection,
  });

  @override
  State<_AdditionalFoodsPickerSheet> createState() =>
      _AdditionalFoodsPickerSheetState();
}

class _AdditionalFoodsPickerSheetState
    extends State<_AdditionalFoodsPickerSheet> {
  static final Map<String, List<ExcludedIngredient>> _searchCache = {};

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualEntryController = TextEditingController();
  // Resolved from the shared app-wide Provider in initState so rate-limit
  // backoff state is shared with every other screen that searches
  // ingredients, instead of each screen tracking its own.
  late final SpoonacularIngredientRepository _repository;
  late final List<ExcludedIngredient> _localIngredients;
  late List<ExcludedIngredient> _selected;
  List<ExcludedIngredient> _results = const [];
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final repository =
        Provider.of<IngredientRepository>(context, listen: false);
    _repository = repository is SpoonacularIngredientRepository
        ? repository
        : SpoonacularIngredientRepository();
    _selected = List.from(widget.initialSelection);
    _localIngredients = _buildLocalIngredients();
    _results = _localIngredients;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _manualEntryController.dispose();
    super.dispose();
  }

  List<ExcludedIngredient> _buildLocalIngredients() {
    final rawItems = [
      ...commonFoodPantryItems.values.expand((items) => items),
      ...commonOtherPantryItems.values.expand((items) => items),
    ];
    final unique = <String, ExcludedIngredient>{};
    for (final item in rawItems) {
      final displayName = (item['name'] ?? '').toString().trim();
      final normalized = ExcludedIngredient.normalize(displayName);
      if (normalized.isEmpty) continue;
      unique.putIfAbsent(
        normalized,
        () => ExcludedIngredient(
          id: 'pantry:${item['id'] ?? normalized}',
          name: normalized,
          displayName: displayName,
          source: 'pantry',
          aliases: [displayName],
        ),
      );
    }
    final values = unique.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return values;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim().toLowerCase();
    final localMatches = _localIngredients
        .where((item) => item.displayName.toLowerCase().contains(query))
        .toList();

    setState(() {
      _results = query.isEmpty ? _localIngredients : localMatches;
      _isSearching = query.length >= 2;
    });

    if (query.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchRemote(query, localMatches);
    });
  }

  Future<void> _searchRemote(
    String query,
    List<ExcludedIngredient> localMatches,
  ) async {
    final cached = _searchCache[query];
    final remote = cached ??
        (await _repository.autocompleteIngredient(query: query, number: 20))
            .map(
              (ingredient) => ExcludedIngredient(
                id: ingredient.id,
                name: ExcludedIngredient.normalize(ingredient.name),
                displayName: ingredient.name,
                source: 'spoonacular',
                aliases: [ingredient.name],
              ),
            )
            .toList();
    _searchCache[query] = remote;

    if (!mounted || _searchController.text.trim().toLowerCase() != query) {
      return;
    }

    final combined = <String, ExcludedIngredient>{};
    for (final item in [...remote, ...localMatches]) {
      combined.putIfAbsent(item.name, () => item);
    }
    setState(() {
      _results = combined.values.toList();
      _isSearching = false;
    });
  }

  void _toggle(ExcludedIngredient ingredient) {
    setState(() {
      if (_selected.contains(ingredient)) {
        _selected.remove(ingredient);
      } else {
        _selected.add(ingredient);
      }
    });
  }

  void _addManualIngredient() {
    final trimmed = _manualEntryController.text.trim();
    if (trimmed.isEmpty) return;

    final normalized = ExcludedIngredient.normalize(trimmed);
    if (normalized.isEmpty) return;

    final candidate = ExcludedIngredient(
      id: 'custom:$normalized',
      name: normalized,
      displayName: trimmed,
      source: 'custom',
      aliases: [trimmed],
    );

    if (_selected.contains(candidate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$trimmed is already in your list.')),
      );
      return;
    }

    setState(() {
      _selected.add(candidate);
      _manualEntryController.clear();
    });
  }

  Future<void> _clearAll() async {
    if (_selected.isEmpty) return;
    final confirmed = await _confirmClearAllIngredients(context);
    if (!confirmed) return;
    setState(() {
      _selected = [];
      _manualEntryController.clear();
    });
  }

  Widget _buildIngredientTile(ExcludedIngredient ingredient) {
    return CheckboxListTile(
      value: _selected.contains(ingredient),
      onChanged: (_) => _toggle(ingredient),
      activeColor: const Color(0xFFFF6A00),
      title: Text(
        ingredient.displayName,
        style: const TextStyle(fontFamily: 'BricolageGrotesque'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Additional Foods to Avoid',
                          style: TextStyle(
                            fontFamily: 'BricolageGrotesque',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_selected.isNotEmpty)
                        TextButton(
                          onPressed: _clearAll,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontFamily: 'BricolageGrotesque',
                              color: Color(0xFF5F5F6E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, _selected),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontFamily: 'BricolageGrotesque',
                            color: Color(0xFFFF6A00),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search ingredients',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView(
                      children: [
                        if (_selected.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                            child: Text(
                              'Selected',
                              style: TextStyle(
                                fontFamily: 'BricolageGrotesque',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (List<ExcludedIngredient>.of(_selected)
                                    ..sort(
                                      (a, b) => a.displayName
                                          .compareTo(b.displayName),
                                    ))
                                  .map(
                                    (ingredient) => InputChip(
                                      label: Text(ingredient.displayName),
                                      labelStyle: const TextStyle(
                                        fontFamily: 'BricolageGrotesque',
                                        color: Color(0xFFFF6A00),
                                      ),
                                      backgroundColor: const Color(
                                        0xFFFFEFE7,
                                      ),
                                      deleteIconColor: const Color(
                                        0xFFFF6A00,
                                      ),
                                      onDeleted: () => _toggle(ingredient),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const Divider(height: 24),
                        ],
                        if (_results.isEmpty && !_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No matching ingredients found',
                                style: TextStyle(
                                  fontFamily: 'BricolageGrotesque',
                                ),
                              ),
                            ),
                          )
                        else
                          ..._results.map(_buildIngredientTile),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Can't find your ingredient?",
                        style: TextStyle(
                          fontFamily: 'BricolageGrotesque',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualEntryController,
                              onSubmitted: (_) => _addManualIngredient(),
                              style: const TextStyle(
                                fontFamily: 'BricolageGrotesque',
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter ingredient',
                                hintStyle: const TextStyle(
                                  fontFamily: 'BricolageGrotesque',
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8F8F8),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addManualIngredient,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6A00),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Add',
                              style:
                                  TextStyle(fontFamily: 'BricolageGrotesque'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
