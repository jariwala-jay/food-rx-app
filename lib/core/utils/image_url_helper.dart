class ImageUrlHelper {
  // Standardized Spoonacular image base URL
  static const String spoonacularBaseUrl = 'https://spoonacular.com/cdn/ingredients_100x100/';
  static const String spoonacularFallbackUrl = 'https://spoonacular.com/cdn/ingredients_100x100/no-image.jpg';

  /// Constructs a proper Spoonacular image URL from various input formats
  /// Handles cases where the input might be:
  /// - Just a filename (e.g., "avocado.jpg")
  /// - A full URL (e.g., "https://spoonacular.com/cdn/ingredients_100x100/avocado.jpg")
  /// - A different base URL format (e.g., "https://img.spoonacular.com/ingredients_100x100/avocado.jpg")
  /// - An empty or null value
  static String getSpoonacularImageUrl(String? imageInput) {
    if (imageInput == null || imageInput.isEmpty) {
      return spoonacularFallbackUrl;
    }

    // If it's already a full URL with the correct base, return as-is
    if (imageInput.startsWith(spoonacularBaseUrl)) {
      return imageInput;
    }

    // If it's a full URL with a different Spoonacular base, extract the filename
    if (imageInput.startsWith('https://') && imageInput.contains('spoonacular.com')) {
      final uri = Uri.tryParse(imageInput);
      if (uri != null) {
        final filename = uri.pathSegments.last;
        return '$spoonacularBaseUrl$filename';
      }
    }

    // If it's a full URL with a different domain, return as-is (external image)
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
    
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return validExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  /// Gets a fallback image URL if the provided URL is invalid
  static String getValidImageUrl(String? imageInput) {
    final processedUrl = getSpoonacularImageUrl(imageInput);
    return isValidImageUrl(processedUrl) ? processedUrl : spoonacularFallbackUrl;
  }
} 