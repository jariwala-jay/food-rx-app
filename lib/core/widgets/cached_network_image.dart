import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CachedNetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? fallbackAssetPath;
  final IconData? fallbackIcon;
  final Color? fallbackIconColor;
  final Color? fallbackBackgroundColor;
  final VoidCallback? onLoadError;

  const CachedNetworkImageWidget({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackAssetPath,
    this.fallbackIcon,
    this.fallbackIconColor,
    this.fallbackBackgroundColor,
    this.onLoadError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('asset:')) {
      final path = imageUrl.substring('asset:'.length);
      Widget imageWidget = Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
      );
      if (borderRadius != null) {
        imageWidget = ClipRRect(
          borderRadius: borderRadius!,
          child: imageWidget,
        );
      }
      return imageWidget;
    }

    // Check if URL is empty or invalid
    if (imageUrl.isEmpty || !_isValidUrl(imageUrl)) {
      return _buildFallbackImage();
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: borderRadius,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6A00),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        if (onLoadError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onLoadError!());
          return Container(
            width: width,
            height: height,
            color: fallbackBackgroundColor ?? Colors.grey[100],
          );
        }
        return _buildFallbackImage();
      },
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Widget _buildFallbackImage() {
    // If we have a fallback asset image, try to use it
    if (fallbackAssetPath != null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image.asset(
            fallbackAssetPath!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              // If asset also fails, show icon fallback
              return _buildIconFallback();
            },
          ),
        ),
      );
    }

    return _buildIconFallback();
  }

  Widget _buildIconFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackBackgroundColor ?? Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fallbackIcon ?? Icons.restaurant_menu,
              size: (height != null && height! > 100) ? 48 : 32,
              color: fallbackIconColor ?? Colors.grey[400],
            ),
            if (height != null && height! > 100) ...[
              const SizedBox(height: 8),
              Text(
                'Recipe Image',
                style: TextStyle(
                  color: fallbackIconColor ?? Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Specialized widget for recipe images (tries alternate Spoonacular CDN URLs on failure).
class RecipeImage extends StatefulWidget {
  final String imageUrl;
  final List<String>? imageUrlCandidates;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const RecipeImage({
    Key? key,
    required this.imageUrl,
    this.imageUrlCandidates,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<RecipeImage> createState() => _RecipeImageState();
}

class _RecipeImageState extends State<RecipeImage> {
  static const _bgColor = Color(0xFFFEF7F0);
  static const _accentColor = Color(0xFFFF6A00);

  late List<String> _candidates;
  int _candidateIndex = 0;
  bool _exhausted = false;
  String? _pendingRetryUrl;

  @override
  void initState() {
    super.initState();
    _candidates = _buildCandidates();
  }

  @override
  void didUpdateWidget(covariant RecipeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageUrlCandidates != widget.imageUrlCandidates) {
      _candidates = _buildCandidates();
      _candidateIndex = 0;
      _exhausted = false;
      _pendingRetryUrl = null;
    }
  }

  List<String> _buildCandidates() {
    final urls = <String>[
      if (widget.imageUrlCandidates != null) ...widget.imageUrlCandidates!,
      if (widget.imageUrl.isNotEmpty) widget.imageUrl,
    ];
    return urls
        .where((u) => u.isNotEmpty && _isValidUrl(u))
        .toSet()
        .toList();
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String? get _currentUrl =>
      _candidates.isNotEmpty && _candidateIndex < _candidates.length
          ? _candidates[_candidateIndex]
          : null;

  void _advanceToNextUrl() {
    final failed = _currentUrl;
    if (failed == null) {
      setState(() => _exhausted = true);
      return;
    }
    if (_pendingRetryUrl == failed) return;
    _pendingRetryUrl = failed;

    if (_candidateIndex + 1 < _candidates.length) {
      setState(() {
        _candidateIndex++;
        _pendingRetryUrl = null;
      });
    } else {
      setState(() {
        _exhausted = true;
        _pendingRetryUrl = null;
      });
    }
  }

  Widget _loadingBox() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: _bgColor,
      child: const Center(
        child: CircularProgressIndicator(
          color: _accentColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _iconFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: (widget.height != null && widget.height! > 100) ? 48 : 32,
              color: _accentColor,
            ),
            if (widget.height != null && widget.height! > 100) ...[
              const SizedBox(height: 8),
              Text(
                'Recipe Image',
                style: TextStyle(
                  color: _accentColor.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_exhausted || _currentUrl == null) {
      return _clipIfNeeded(_iconFallback());
    }

    Widget image = Image.network(
      _currentUrl!,
      key: ValueKey(_currentUrl),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _loadingBox();
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _advanceToNextUrl();
        });
        return _loadingBox();
      },
    );

    return _clipIfNeeded(image);
  }

  Widget _clipIfNeeded(Widget child) {
    if (widget.borderRadius == null) return child;
    return ClipRRect(
      borderRadius: widget.borderRadius!,
      child: child,
    );
  }
}

// Specialized widget for ingredient images
class IngredientImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const IngredientImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImageWidget(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      fallbackIcon: Icons.eco,
      fallbackIconColor: Colors.green[400],
      fallbackBackgroundColor: Colors.green[50],
    );
  }
}

// Specialized widget for article images
class ArticleImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ArticleImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImageWidget(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      fallbackIcon: Icons.article,
      fallbackIconColor: Colors.blue[400],
      fallbackBackgroundColor: Colors.blue[50],
    );
  }
} 