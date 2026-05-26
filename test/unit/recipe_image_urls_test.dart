import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/utils/recipe_image_urls.dart';

void main() {
  group('RecipeImageUrls.resolveFromJson', () {
    test('uses API image URL when present', () {
      expect(
        RecipeImageUrls.resolveFromJson({
          'id': 642499,
          'image': 'https://img.spoonacular.com/recipes/642499-312x231.jpg',
        }),
        'https://img.spoonacular.com/recipes/642499-312x231.jpg',
      );
    });

    test('builds CDN URL from id when image missing', () {
      expect(
        RecipeImageUrls.resolveFromJson({'id': 642499}),
        'https://img.spoonacular.com/recipes/642499-556x370.jpg',
      );
    });

    test('uses imageType png for CDN fallback', () {
      expect(
        RecipeImageUrls.resolveFromJson({
          'id': 681713,
          'imageType': 'png',
        }),
        'https://img.spoonacular.com/recipes/681713-556x370.png',
      );
    });

    test('resolves relative image with baseUri', () {
      expect(
        RecipeImageUrls.resolveFromJson({
          'id': 991010,
          'image': '991010-312x231.jpg',
          'baseUri': 'https://img.spoonacular.com/recipes/',
        }),
        'https://img.spoonacular.com/recipes/991010-312x231.jpg',
      );
    });
  });

  group('RecipeImageUrls.candidatesFor', () {
    test('includes API url and CDN fallbacks', () {
      final urls = RecipeImageUrls.candidatesFor(
        id: 642499,
        image: 'https://img.spoonacular.com/recipes/642499-312x231.jpg',
        imageType: 'jpg',
      );
      expect(urls.first, contains('642499-312x231.jpg'));
      expect(
        urls.any((u) => u.contains('img.spoonacular.com/recipes/642499-556x370')),
        isTrue,
      );
      expect(
        urls.any((u) => u.contains('spoonacular.com/recipeImages')),
        isTrue,
      );
    });
  });
}
