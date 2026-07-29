class ImageUrlHelper {
  // Standardized Spoonacular image base URL
  static const String spoonacularBaseUrl = 'https://spoonacular.com/cdn/ingredients_100x100/';
  static const String spoonacularFallbackUrl = 'https://spoonacular.com/cdn/ingredients_100x100/no-image.jpg';

  /// Normalizes a Spoonacular image reference (bare filename, full URL, or
  /// an alternate base URL) to our standard base URL.
  static String getSpoonacularImageUrl(String? imageInput) {
    if (imageInput == null || imageInput.isEmpty) {
      return spoonacularFallbackUrl;
    }

    if (imageInput.startsWith('asset:')) {
      return imageInput;
    }

    // If it's already a full URL with the correct base, return as-is
    if (imageInput.startsWith(spoonacularBaseUrl)) {
      return imageInput;
    }

    // Any absolute URL: return unchanged. Rewriting img.spoonacular.com URLs
    // to ingredients_100x100 often 404s for some ingredients (e.g. ground turkey).
    if (imageInput.startsWith('http://') || imageInput.startsWith('https://')) {
      return imageInput;
    }

    // If it's just a filename, prepend the base URL
    return '$spoonacularBaseUrl$imageInput';
  }

  /// Validates if an image URL is accessible (basic format check)
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    final host = uri.host.toLowerCase();
    if (host.contains('spoonacular.com')) {
      return true;
    }

    final path = uri.path.toLowerCase();
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return validExtensions.any((ext) => path.endsWith(ext));
  }

  /// Gets a fallback image URL if the provided URL is invalid
  static String getValidImageUrl(String? imageInput) {
    final processedUrl = getSpoonacularImageUrl(imageInput);
    if (processedUrl.startsWith('asset:')) {
      return processedUrl;
    }
    return isValidImageUrl(processedUrl) ? processedUrl : spoonacularFallbackUrl;
  }
} 