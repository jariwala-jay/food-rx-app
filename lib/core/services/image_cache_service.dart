import 'package:cached_network_image/cached_network_image.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, CachedNetworkImageProvider> _imageProviders = {};

  CachedNetworkImageProvider getImageProvider(String imageUrl) {
    if (!_imageProviders.containsKey(imageUrl)) {
      _imageProviders[imageUrl] = CachedNetworkImageProvider(
        imageUrl,
        maxWidth: 800,
        maxHeight: 800,
      );
    }
    return _imageProviders[imageUrl]!;
  }

  void clearCache() {
    _imageProviders.clear();
  }
}
