import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/ingredient_category_mapper.dart';

void main() {
  group('IngredientCategoryMapper.resolveCategory', () {
    test('resolves the spec examples by name alone', () {
      expect(IngredientCategoryMapper.resolveCategory(name: 'Plantain'),
          'fresh_fruits');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Banana'),
          'fresh_fruits');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Tofu'), 'beans');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Chickpeas'),
          'beans');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Paneer'),
          'dairy');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Yogurt'),
          'dairy');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Quinoa'),
          'grains');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Oats'), 'grains');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Almonds'),
          'nuts_seeds');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Cumin'),
          'seasonings');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Chicken'),
          'meat');
    });

    test('preserved-form vegetables resolve to canned_veggies', () {
      expect(IngredientCategoryMapper.resolveCategory(name: 'Pickled onions'),
          'canned_veggies');
      expect(
          IngredientCategoryMapper.resolveCategory(name: 'Kimchi'),
          // Kimchi itself has no preserve-form keyword in the name, so it
          // lands in the default (fresh) leaf for the vegetable bucket.
          'fresh_veggies');
    });

    test('frozen-form fruit resolves to frozen_fruits', () {
      expect(IngredientCategoryMapper.resolveCategory(name: 'Frozen mango'),
          'frozen_fruits');
    });

    test('disambiguates pepper by qualifier', () {
      expect(IngredientCategoryMapper.resolveCategory(name: 'Black pepper'),
          'seasonings');
      expect(IngredientCategoryMapper.resolveCategory(name: 'White pepper'),
          'seasonings');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Ground pepper'),
          'seasonings');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Peppercorn'),
          'seasonings');
      expect(
          IngredientCategoryMapper.resolveCategory(name: 'Red pepper flakes'),
          'seasonings');
      expect(
          IngredientCategoryMapper.resolveCategory(name: 'Crushed red pepper'),
          'seasonings');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Bell pepper'),
          'fresh_veggies');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Green pepper'),
          'fresh_veggies');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Red pepper'),
          'fresh_veggies');
      expect(
          IngredientCategoryMapper.resolveCategory(name: 'Green bell pepper'),
          'fresh_veggies');
      expect(
          IngredientCategoryMapper.resolveCategory(name: 'Green bell peppers'),
          'fresh_veggies');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Sweet pepper'),
          'fresh_veggies');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Capsicum'),
          'fresh_veggies');
      expect(IngredientCategoryMapper.resolveCategory(name: 'Pepper'),
          'fresh_veggies');
    });

    test('word boundaries avoid false-positive substrings', () {
      expect(IngredientCategoryMapper.resolveCategory(name: 'Pearl onion'),
          'fresh_veggies'); // not fruit via "pear"
      expect(IngredientCategoryMapper.resolveCategory(name: 'Popcorn'),
          'miscellaneous'); // not vegetable via "corn"
      expect(IngredientCategoryMapper.resolveCategory(name: 'Chickpea'),
          'beans'); // not fruit via "pea"/"chickpea"
    });

    test('falls back to a reliable aisle when name gives no match', () {
      expect(
          IngredientCategoryMapper.resolveCategory(
              name: 'Furikake', aisle: 'Meat'),
          'meat');
    });

    test('ignores broad/unreliable aisles and falls back to miscellaneous',
        () {
      expect(
          IngredientCategoryMapper.resolveCategory(
              name: 'Furikake', aisle: 'Produce'),
          'miscellaneous');
      expect(
          IngredientCategoryMapper.resolveCategory(
              name: 'Furikake', aisle: 'Ethnic Foods'),
          'miscellaneous');
      expect(
          IngredientCategoryMapper.resolveCategory(
              name: 'Furikake', aisle: 'Refrigerated'),
          'miscellaneous');
    });

    test('genuinely unrecognizable name with no aisle is miscellaneous', () {
      expect(IngredientCategoryMapper.resolveCategory(name: 'Furikake'),
          'miscellaneous');
    });

    test('empty name is miscellaneous', () {
      expect(IngredientCategoryMapper.resolveCategory(name: ''),
          'miscellaneous');
    });
  });
}
