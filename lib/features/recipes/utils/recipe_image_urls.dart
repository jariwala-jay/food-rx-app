/// Spoonacular recipe image URL resolution and CDN fallbacks.
class RecipeImageUrls {
  static const _imgCdn = 'https://img.spoonacular.com/recipes';
  static const _legacyRecipeImages = 'https://spoonacular.com/recipeImages';
  static const _legacyRecipes = 'https://spoonacular.com/recipes';

  /// Primary display URL from a Spoonacular search/detail payload.
  static String resolveFromJson(Map<String, dynamic> json) {
    final raw = (json['image'] as String?)?.trim() ?? '';
    final normalized = _normalizeAbsoluteUrl(raw, json);
    if (normalized != null) return normalized;

    final id = _recipeId(json);
    if (id != null && id > 0) {
      final ext = _preferredExtension(json, raw);
      return '$_imgCdn/$id-556x370.$ext';
    }

    final ingredientUrl = _firstIngredientImageUrl(json);
    if (ingredientUrl != null) return ingredientUrl;

    return '';
  }

  /// Ordered URLs to try when the primary image fails to load.
  static List<String> candidatesFor({
    required int id,
    required String image,
    String? imageType,
    Iterable<String> ingredientImageUrls = const [],
  }) {
    final seen = <String>{};
    final out = <String>[];

    void add(String? url) {
      if (url == null || url.isEmpty) return;
      if (seen.add(url)) out.add(url);
    }

    add(_normalizeAbsoluteUrl(image, const {}));

    if (id > 0) {
      final extensions = _extensionOrder(imageType, image);
      for (final size in ['312x231', '556x370']) {
        for (final ext in extensions.take(2)) {
          add('$_imgCdn/$id-$size.$ext');
        }
      }
      add('$_legacyRecipeImages/$id-312x231.jpg');
      add('$_legacyRecipes/$id-312x231.jpg');
    }

    for (final url in ingredientImageUrls) {
      add(url.startsWith('http') ? url : null);
    }

    // Keep the retry list short so failed loads reach a working URL quickly.
    return out.take(10).toList();
  }

  static bool hasResolvableImage({required int id, required String image}) =>
      image.isNotEmpty || id > 0;

  static String? _normalizeAbsoluteUrl(
    String raw,
    Map<String, dynamic> json,
  ) {
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return _isValidHttpUrl(raw) ? raw : null;
    }

    final baseUri = (json['baseUri'] as String?)?.trim();
    if (baseUri != null && baseUri.isNotEmpty) {
      final base = baseUri.endsWith('/') ? baseUri : '$baseUri/';
      final path = raw.startsWith('/') ? raw.substring(1) : raw;
      final combined = '$base$path';
      return _isValidHttpUrl(combined) ? combined : null;
    }

    if (raw.contains('.jpg') ||
        raw.contains('.jpeg') ||
        raw.contains('.png') ||
        raw.contains('.webp')) {
      return '$_imgCdn/${raw.startsWith('/') ? raw.substring(1) : raw}';
    }

    return null;
  }

  static int? _recipeId(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static String _preferredExtension(Map<String, dynamic> json, String rawImage) {
    final fromType = (json['imageType'] as String?)?.trim().toLowerCase();
    if (fromType == 'png' || fromType == 'jpg' || fromType == 'jpeg') {
      return fromType == 'jpeg' ? 'jpg' : fromType!;
    }
    return _extensionFromUrl(rawImage) ?? 'jpg';
  }

  static List<String> _extensionOrder(String? imageType, String imageUrl) {
    final ordered = <String>[];
    void addExt(String? ext) {
      if (ext == null || ext.isEmpty) return;
      final normalized = ext == 'jpeg' ? 'jpg' : ext;
      if (!ordered.contains(normalized)) ordered.add(normalized);
    }

    addExt(imageType?.toLowerCase());
    addExt(_extensionFromUrl(imageUrl));
    addExt('jpg');
    addExt('png');
    return ordered;
  }

  static String? _extensionFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.webp')) return 'webp';
    return null;
  }

  static String? _firstIngredientImageUrl(Map<String, dynamic> json) {
    final ingredients = json['extendedIngredients'] as List<dynamic>?;
    if (ingredients == null) return null;
    for (final item in ingredients) {
      if (item is! Map<String, dynamic>) continue;
      final img = (item['image'] as String?)?.trim() ?? '';
      if (img.startsWith('http')) return img;
    }
    return null;
  }

  static bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
