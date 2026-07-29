import 'package:flutter/foundation.dart';

@immutable
class ExcludedIngredient {
  final String id;
  final String name;
  final String displayName;
  final String source;
  final List<String> aliases;

  const ExcludedIngredient({
    required this.id,
    required this.name,
    required this.displayName,
    required this.source,
    this.aliases = const [],
  });

  factory ExcludedIngredient.fromJson(dynamic value) {
    if (value is String) {
      final normalized = normalize(value);
      return ExcludedIngredient(
        id: 'legacy:$normalized',
        name: normalized,
        displayName: _titleCase(value.trim()),
        source: 'legacy',
        aliases: [value],
      );
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final rawName =
          (map['name'] ?? map['displayName'] ?? map['id'] ?? '').toString();
      final normalized = normalize(rawName);
      final source = (map['source'] ?? 'legacy').toString();
      return ExcludedIngredient(
        id: (map['id'] ?? '$source:$normalized').toString(),
        name: normalized,
        displayName:
            (map['displayName'] ?? _titleCase(rawName)).toString().trim(),
        source: source,
        aliases: (map['aliases'] as List?)
                ?.map((alias) => alias.toString())
                .toList() ??
            const [],
      );
    }

    throw FormatException('Unsupported excluded ingredient: $value');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'displayName': displayName,
        'source': source,
        if (aliases.isNotEmpty) 'aliases': aliases,
      };

  Iterable<String> get normalizedAliases sync* {
    yield normalize(name);
    yield normalize(displayName);
    for (final alias in aliases) {
      yield normalize(alias);
    }
  }

  bool matches(String ingredientText) {
    final candidate = normalize(ingredientText);
    if (candidate.isEmpty) return false;
    final candidateTokens = candidate.split(' ').toSet();

    for (final alias in normalizedAliases.toSet()) {
      if (alias.isEmpty) continue;
      final aliasTokens = alias.split(' ');
      if (aliasTokens.every(candidateTokens.contains)) return true;
    }
    return false;
  }

  static String normalize(String value) {
    const ignoredWords = {
      'fresh',
      'frozen',
      'canned',
      'dried',
      'dry',
      'raw',
      'cooked',
      'chopped',
      'diced',
      'minced',
      'sliced',
      'slice',
      'slices',
      'whole',
      'small',
      'medium',
      'large',
      'organic',
    };

    final words = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !ignoredWords.contains(word))
        .map(_singularize);
    return words.join(' ').trim();
  }

  static String _singularize(String word) {
    if (word.length > 4 && word.endsWith('ies')) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.length > 4 &&
        (word.endsWith('ches') ||
            word.endsWith('shes') ||
            word.endsWith('xes') ||
            word.endsWith('zes'))) {
      return word.substring(0, word.length - 2);
    }
    if (word.length > 3 &&
        word.endsWith('s') &&
        !word.endsWith('ss') &&
        !word.endsWith('us')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  static String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExcludedIngredient && normalize(other.name) == normalize(name);

  @override
  int get hashCode => normalize(name).hashCode;
}
