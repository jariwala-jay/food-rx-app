import 'package:flutter/foundation.dart';

/// Enhanced Universal Conversion Service (UCS) for Food Rx
/// Provides comprehensive unit conversion with density-based transformations
/// Supports recipe scaling, pantry deduction, and diet serving calculations
class UnitConversionService {
  // --- Ratio-based Converters ---

  // Volume conversions (base unit: milliliters)
  static const Map<String, double> _volumeToMl = {
    'cup': 236.588,
    'fluid ounce': 29.5735,
    'tablespoon': 14.7868,
    'teaspoon': 4.92892,
    'ml': 1.0,
    'milliliter': 1.0,
    'liter': 1000.0,
    'gallon': 3785.41,
    'quart': 946.353,
    'pint': 473.176,
    // Additional common volume units
    'fl oz': 29.5735,
    'tbsp': 14.7868,
    'tsp': 4.92892,
    'l': 1000.0,
    'gal': 3785.41,
    'qt': 946.353,
    'pt': 473.176,
  };

  // Weight conversions (base unit: grams)
  static const Map<String, double> _weightToGrams = {
    'gram': 1.0,
    'g': 1.0,
    'kilogram': 1000.0,
    'kg': 1000.0,
    'ounce': 28.3495,
    'oz': 28.3495,
    'pound': 453.592,
    'lb': 453.592,
    'lbs': 453.592,
  };

  // --- Enhanced Ingredient-Specific Density Data (g/mL) ---
  // Source: USDA FoodData Central SR-Legacy and cooking resources
  static final Map<String, double> _ingredientDensities = {
    // Liquids
    'water': 1.0,
    'milk': 1.03,
    'whole milk': 1.03,
    'skim milk': 1.03,
    'almond milk': 1.03,
    'soy milk': 1.03,
    'oat milk': 1.03,
    'coconut milk': 0.97,
    'heavy cream': 0.99,
    'half and half': 1.01,
    'buttermilk': 1.03,
    
    // Oils and Fats
    'oil': 0.92,
    'vegetable oil': 0.92,
    'olive oil': 0.92,
    'canola oil': 0.92,
    'coconut oil': 0.92,
    'butter': 0.91,
    'margarine': 0.91,
    'lard': 0.92,
    'shortening': 0.91,
    
    // Flours and Grains
    'flour': 0.53,
    'all-purpose flour': 0.53,
    'whole wheat flour': 0.53,
    'bread flour': 0.53,
    'bread crumbs': 0.40,
    'breadcrumbs': 0.40,
    'cake flour': 0.45,
    'rice flour': 0.58,
    'almond flour': 0.40,
    'coconut flour': 0.48,
    'rice': 0.85,
    'white rice': 0.85,
    'brown rice': 0.85,
    'quinoa': 0.85,
    'oats': 0.41,
    'rolled oats': 0.41,
    'barley': 0.69,
    'wheat': 0.78,
    'pasta': 0.85,
    'couscous': 0.85,
    
    // Sugars and Sweeteners
    'sugar': 0.84,
    'white sugar': 0.84,
    'brown sugar': 0.90,
    'powdered sugar': 0.56,
    'honey': 1.42,
    'maple syrup': 1.32,
    'corn syrup': 1.48,
    'molasses': 1.40,
    'agave': 1.35,
    
    // Proteins
    'chicken': 0.70,
    'chicken breast': 0.70,
    'chicken thigh': 0.70,
    'ground chicken': 0.70,
    'beef': 0.60,
    'ground beef': 0.60,
    'steak': 0.60,
    'pork': 0.65,
    'ground pork': 0.65,
    'bacon': 0.50,
    'turkey': 0.70,
    'ground turkey': 0.70,
    'fish': 0.75,
    'salmon': 0.75,
    'tuna': 0.75,
    'shrimp': 0.85,
    'crab': 0.85,
    'lobster': 0.85,
    'tofu': 1.03,
    'tempeh': 0.85,
    'seitan': 0.90,
    
    // Vegetables
    'onion': 0.60,
    'yellow onion': 0.60,
    'white onion': 0.60,
    'red onion': 0.60,
    'garlic': 0.60,
    'carrot': 0.60,
    'celery': 0.60,
    'bell pepper': 0.55,
    'tomato': 0.70,
    'tomatoes': 0.70,
    'potato': 0.78,
    'sweet potato': 0.78,
    'broccoli': 0.35,
    'cauliflower': 0.35,
    'spinach': 0.25,
    'lettuce': 0.25,
    'cucumber': 0.60,
    'zucchini': 0.60,
    'mushrooms': 0.35,
    'corn': 0.72,
    'peas': 0.85,
    'green beans': 0.45,
    'asparagus': 0.45,
    'cabbage': 0.40,
    'kale': 0.25,
    'avocado': 0.90,
    
    // Fruits
    'apple': 0.85,
    'banana': 0.60,
    'orange': 0.85,
    'lemon': 0.85,
    'lime': 0.85,
    'strawberry': 0.60,
    'blueberry': 0.60,
    'raspberry': 0.60,
    'blackberry': 0.60,
    'grape': 0.85,
    'peach': 0.85,
    'pear': 0.85,
    'plum': 0.85,
    'mango': 0.85,
    'pineapple': 0.85,
    'kiwi': 0.85,
    'watermelon': 0.92,
    'cantaloupe': 0.90,
    'honeydew': 0.90,
    
    // Dairy
    'cheese': 1.00,
    'cheddar cheese': 1.00,
    'mozzarella cheese': 1.00,
    'parmesan cheese': 1.15,
    'cream cheese': 1.00,
    'cottage cheese': 1.00,
    'ricotta cheese': 1.00,
    'yogurt': 1.03,
    'greek yogurt': 1.03,
    'sour cream': 0.96,
    
    // Nuts and Seeds
    'almonds': 0.60,
    'walnuts': 0.52,
    'pecans': 0.69,
    'cashews': 0.59,
    'peanuts': 0.64,
    'sunflower seeds': 0.52,
    'pumpkin seeds': 0.56,
    'chia seeds': 0.52,
    'flax seeds': 0.53,
    'sesame seeds': 0.57,
    
    // Legumes
    'beans': 0.85,
    'black beans': 0.85,
    'kidney beans': 0.85,
    'pinto beans': 0.85,
    'navy beans': 0.85,
    'chickpeas': 0.85,
    'lentils': 0.85,
    'split peas': 0.85,
    
    // Seasonings and Spices
    'salt': 1.20,
    'pepper': 0.50,
    'paprika': 0.50,
    'cumin': 0.50,
    'oregano': 0.30,
    'basil': 0.30,
    'thyme': 0.30,
    'rosemary': 0.30,
    'cinnamon': 0.50,
    'nutmeg': 0.50,
    'ginger': 0.60,
    'turmeric': 0.50,
    'chili powder': 0.50,
    'garlic powder': 0.50,
    'onion powder': 0.50,
    
    // Baking ingredients
    'baking powder': 0.90,
    'baking soda': 2.20,
    'vanilla extract': 0.88,
    'cocoa powder': 0.52,
    'chocolate chips': 0.85,
    'raisins': 0.85,
    'dates': 0.85,
    'cranberries': 0.60,
    
    // Condiments
    'ketchup': 1.10,
    'mustard': 1.05,
    'mayonnaise': 0.91,
    'vinegar': 1.01,
    'soy sauce': 1.15,
    'worcestershire sauce': 1.10,
    'hot sauce': 1.05,
    'barbecue sauce': 1.10,
    'salsa': 1.00,
    'pesto': 0.95,
    
    // Beverages
    'coffee': 1.00,
    'tea': 1.00,
    'juice': 1.04,
    'orange juice': 1.04,
    'apple juice': 1.04,
    'grape juice': 1.04,
    'cranberry juice': 1.04,
    'wine': 0.99,
    'beer': 1.01,
    'soda': 1.04,
    'broth': 1.00,
    'chicken broth': 1.00,
    'vegetable broth': 1.00,
    'beef broth': 1.00,
  };

  // --- Enhanced Piece-to-Gram Conversions ---
  static final Map<String, double> _pieceToGrams = {
    // Eggs
    'egg': 50.0,
    'large egg': 50.0,
    'medium egg': 44.0,
    'small egg': 38.0,
    'extra large egg': 56.0,
    'jumbo egg': 63.0,
    'egg white': 33.0,
    'egg yolk': 17.0,
    
    // Garlic
    'clove of garlic': 3.0,
    'garlic clove': 3.0,
    'clove': 3.0,
    'head of garlic': 40.0,
    'bulb of garlic': 40.0,
    
    // Bread
    'slice of bread': 28.0,
    'bread slice': 28.0,
    'slice': 28.0,
    'dinner roll': 28.0,
    'hamburger bun': 43.0,
    'hot dog bun': 43.0,
    'bagel': 95.0,
    'english muffin': 57.0,
    'tortilla': 30.0,
    'pita bread': 60.0,
    
    // Meat
    'bacon slice': 12.0,
    'slice of bacon': 12.0,
    'chicken breast': 174.0,
    'chicken thigh': 109.0,
    'chicken wing': 21.0,
    'chicken drumstick': 44.0,
    'pork chop': 150.0,
    'beef patty': 113.0,
    'hamburger patty': 113.0,
    'hot dog': 45.0,
    'sausage link': 25.0,
    
    // Fruits
    'apple': 182.0,
    'medium apple': 182.0,
    'large apple': 223.0,
    'small apple': 149.0,
    'banana': 118.0,
    'medium banana': 118.0,
    'large banana': 136.0,
    'small banana': 101.0,
    'orange': 154.0,
    'medium orange': 154.0,
    'large orange': 184.0,
    'small orange': 96.0,
    'lemon': 60.0,
    'lime': 67.0,
    'peach': 150.0,
    'pear': 178.0,
    'plum': 66.0,
    'strawberry': 12.0,
    'grape': 5.0,
    'cherry': 8.0,
    'date': 7.0,
    'fig': 8.0,
    'kiwi': 69.0,
    'mango': 207.0,
    'avocado': 201.0,
    
    // Vegetables
    'onion': 110.0,
    'medium onion': 110.0,
    'large onion': 150.0,
    'small onion': 70.0,
    'carrot': 61.0,
    'medium carrot': 61.0,
    'large carrot': 72.0,
    'small carrot': 50.0,
    'celery stalk': 40.0,
    'bell pepper': 119.0,
    'tomato': 123.0,
    'medium tomato': 123.0,
    'large tomato': 182.0,
    'small tomato': 91.0,
    'cherry tomato': 17.0,
    'potato': 213.0,
    'medium potato': 213.0,
    'large potato': 299.0,
    'small potato': 170.0,
    'sweet potato': 128.0,
    'cucumber': 301.0,
    'zucchini': 196.0,
    'mushroom': 15.0,
    'portobello mushroom': 84.0,
    'shiitake mushroom': 19.0,
    'corn on the cob': 90.0,
    'ear of corn': 90.0,
    'broccoli floret': 11.0,
    'cauliflower floret': 13.0,
    'lettuce leaf': 10.0,
    'spinach leaf': 2.0,
    'kale leaf': 8.0,
    'cabbage leaf': 33.0,
    'asparagus spear': 16.0,
    'green bean': 4.0,
    'brussels sprout': 21.0,
    'artichoke': 128.0,
    'eggplant': 458.0,
    'radish': 4.5,
    'turnip': 122.0,
    'beet': 82.0,
    'parsnip': 133.0,
    'rutabaga': 386.0,
    'leek': 89.0,
    'shallot': 17.0,
    'scallion': 15.0,
    'green onion': 15.0,
    'jalapeno': 14.0,
    'serrano pepper': 6.0,
    'habanero': 8.5,
    'poblano pepper': 17.0,
    'anaheim pepper': 24.0,
    
    // Nuts and Seeds
    'walnut half': 2.0,
    'pecan half': 1.0,
    'almond': 1.2,
    'cashew': 0.7,
    'peanut': 0.7,
    'pistachio': 0.7,
    'brazil nut': 5.0,
    'hazelnut': 1.0,
    'macadamia nut': 2.0,
    'pine nut': 0.01,
    
    // Dairy
    'slice of cheese': 28.0,
    'cheese slice': 28.0,
    'string cheese': 28.0,
    'mozzarella stick': 28.0,
    'butter pat': 5.0,
    'stick of butter': 113.0,
    'tablespoon butter': 14.0,
    
    // Seafood
    'shrimp': 6.0,
    'large shrimp': 6.0,
    'jumbo shrimp': 12.0,
    'medium shrimp': 4.0,
    'small shrimp': 2.0,
    'scallop': 20.0,
    'oyster': 15.0,
    'clam': 10.0,
    'mussel': 9.0,
    'crab leg': 134.0,
    'lobster tail': 227.0,
    'fish fillet': 150.0,
    'salmon fillet': 150.0,
    'tuna steak': 150.0,
    'cod fillet': 150.0,
    'tilapia fillet': 87.0,
    'catfish fillet': 143.0,
    'halibut fillet': 159.0,
    'mahi mahi fillet': 140.0,
    'snapper fillet': 170.0,
    'sea bass fillet': 125.0,
    'sole fillet': 127.0,
    'flounder fillet': 127.0,
    'trout fillet': 143.0,
    'mackerel fillet': 88.0,
    'sardine': 12.0,
    'anchovy': 4.0,
    
    // Miscellaneous
    'ice cube': 30.0,
    'tea bag': 2.0,
    'coffee bean': 0.13,
    'peppercorn': 0.02,
    'bay leaf': 0.6,
    'cinnamon stick': 2.6,
    'vanilla bean': 2.0,
    'star anise': 0.5,
    'cardamom pod': 0.3,
    'clove': 0.1,
    'juniper berry': 0.3,
    'allspice berry': 0.05,
    'dried chili': 1.0,
    'bouillon cube': 4.0,
    'stock cube': 10.0,
    'crackers': 3.0,
    'graham cracker': 14.0,
    'cookie': 10.0,
    'chocolate chip': 0.5,
    'marshmallow': 7.0,
    'pretzel': 1.0,
    'chip': 0.5,
    'popcorn kernel': 0.02,
    'raisin': 0.5,
    'cranberry': 0.4,
    'olive': 3.0,
    'caper': 0.6,
    'pickle': 35.0,
    'gherkin': 15.0,
    'maraschino cherry': 5.0,
    'date': 7.0,
    'prune': 9.5,
    'apricot': 35.0,
    'fig': 8.0,
  };

  // --- Confidence Scoring ---
  static const double _highConfidence = 0.95;
  static const double _mediumConfidence = 0.85;
  static const double _lowConfidence = 0.70;

  /// Normalizes a unit string to a consistent, singular, lowercase format.
  String _normalizeUnit(String unit) {
    String lowerUnit = unit.toLowerCase().trim();

    const Map<String, String> mappings = {
      // Volume
      'cups': 'cup',
      'cup': 'cup',
      'c': 'cup',
      'fl oz': 'fluid ounce',
      'fluid ounces': 'fluid ounce',
      'fluid ounce': 'fluid ounce',
      'tablespoons': 'tablespoon',
      'tablespoon': 'tablespoon',
      'tbsp': 'tablespoon',
      'tbs': 'tablespoon',
      'teaspoons': 'teaspoon',
      'teaspoon': 'teaspoon',
      'tsp': 'teaspoon',
      'milliliters': 'ml',
      'milliliter': 'ml',
      'ml': 'ml',
      'liters': 'liter',
      'liter': 'liter',
      'l': 'liter',
      'gallons': 'gallon',
      'gallon': 'gallon',
      'gal': 'gallon',
      'quarts': 'quart',
      'quart': 'quart',
      'qt': 'quart',
      'pints': 'pint',
      'pint': 'pint',
      'pt': 'pint',
      // Weight
      'grams': 'gram',
      'gram': 'gram',
      'g': 'gram',
      'kilograms': 'kilogram',
      'kilogram': 'kilogram',
      'kg': 'kilogram',
      'ounces': 'ounce',
      'ounce': 'ounce',
      'oz': 'ounce',
      'pounds': 'pound',
      'pound': 'pound',
      'lbs': 'pound',
      'lb': 'pound',
      // Piece-based (maps to a standard 'piece' for logic)
      'piece': 'piece',
      'pieces': 'piece',
      'pc': 'piece',
      'pcs': 'piece',
      'each': 'piece',
      'whole': 'piece',
      'item': 'piece',
      'items': 'piece',
      'clove': 'piece',
      'cloves': 'piece',
      'slice': 'piece',
      'slices': 'piece',
      'large': 'piece',
      'medium': 'piece',
      'small': 'piece',
      'head': 'piece',
      'heads': 'piece',
      'bulb': 'piece',
      'bulbs': 'piece',
      'stalk': 'piece',
      'stalks': 'piece',
      'spear': 'piece',
      'spears': 'piece',
      'floret': 'piece',
      'florets': 'piece',
      'leaf': 'piece',
      'leaves': 'piece',
      'fillet': 'piece',
      'fillets': 'piece',
      'breast': 'piece',
      'breasts': 'piece',
      'thigh': 'piece',
      'thighs': 'piece',
      'wing': 'piece',
      'wings': 'piece',
      'drumstick': 'piece',
      'drumsticks': 'piece',
      'leg': 'piece',
      'legs': 'piece',
      'chop': 'piece',
      'chops': 'piece',
      'patty': 'piece',
      'patties': 'piece',
      'link': 'piece',
      'links': 'piece',
      'stick': 'piece',
      'sticks': 'piece',
      'cube': 'piece',
      'cubes': 'piece',
      'half': 'piece',
      'halves': 'piece',
      'quarter': 'piece',
      'quarters': 'piece',
      'wedge': 'piece',
      'wedges': 'piece',
      'chunk': 'piece',
      'chunks': 'piece',
      'strip': 'piece',
      'strips': 'piece',
      'ring': 'piece',
      'rings': 'piece',
      'round': 'piece',
      'rounds': 'piece',
      'ear': 'piece',
      'ears': 'piece',
      'pod': 'piece',
      'pods': 'piece',
      'kernel': 'piece',
      'kernels': 'piece',
      'bean': 'piece',
      'berry': 'piece',
      'berries': 'piece',
      'nut': 'piece',
      'nuts': 'piece',
      'seed': 'piece',
      'seeds': 'piece',
      'bag': 'piece',
      'bags': 'piece',
      'can': 'piece',
      'cans': 'piece',
      'bottle': 'piece',
      'bottles': 'piece',
      'jar': 'piece',
      'jars': 'piece',
      'box': 'piece',
      'boxes': 'piece',
      'package': 'piece',
      'packages': 'piece',
      'container': 'piece',
      'containers': 'piece',
      // Other
      '': 'unit', // Default for empty unit strings
      'unit': 'unit',
      'units': 'unit',
      'serving': 'serving',
      'servings': 'serving',
      'portion': 'serving',
      'portions': 'serving',
      'pinch': 'pinch',
      'pinches': 'pinch',
      'dash': 'dash',
      'dashes': 'dash',
      'splash': 'splash',
      'splashes': 'splash',
      'drop': 'drop',
      'drops': 'drop',
      'handful': 'handful',
      'handfuls': 'handful',
      'bunch': 'bunch',
      'bunches': 'bunch',
      'sprig': 'sprig',
      'sprigs': 'sprig',
      'to taste': 'to taste',
    };
    return mappings[lowerUnit] ?? lowerUnit;
  }

  /// Finds the best matching key in a map for a given ingredient name.
  /// Returns both the key and a confidence score.
  Map<String, dynamic> _findBestMatchWithConfidence(
      String ingredientName, Map<String, dynamic> map) {
    final lowerIngredient = ingredientName.toLowerCase().trim();

    // Return null for empty ingredient names
    if (lowerIngredient.isEmpty) {
      return {
        'key': null,
        'confidence': 0.0,
      };
    }

    // Exact match first - highest confidence
    if (map.containsKey(lowerIngredient)) {
      return {
        'key': lowerIngredient,
        'confidence': _highConfidence,
      };
    }

    // Check for keywords where the map key is more specific
    // e.g., recipe says "garlic", map key is "clove of garlic"
    for (final key in map.keys) {
      if (key.contains(lowerIngredient)) {
        return {
          'key': key,
          'confidence': _mediumConfidence,
        };
      }
    }

    // Fallback check for when the ingredient is more specific
    // e.g., recipe says "yellow onion", map key is "onion"
    for (final key in map.keys) {
      if (lowerIngredient.contains(key)) {
        return {
          'key': key,
          'confidence': _mediumConfidence,
        };
      }
    }

    // Check for partial matches with common food words
    final commonWords = ['fresh', 'dried', 'frozen', 'canned', 'raw', 'cooked', 
                        'chopped', 'diced', 'sliced', 'minced', 'grated', 'shredded',
                        'organic', 'whole', 'ground', 'crushed', 'peeled', 'unpeeled'];
    
    for (final word in commonWords) {
      final cleanedIngredient = lowerIngredient.replaceAll(word, '').trim();
      if (cleanedIngredient.isNotEmpty && map.containsKey(cleanedIngredient)) {
        return {
          'key': cleanedIngredient,
          'confidence': _mediumConfidence,
        };
      }
    }

    return {
      'key': null,
      'confidence': 0.0,
    };
  }

  /// Legacy method for backward compatibility
  String? _findBestMatch(String ingredientName, Map<String, dynamic> map) {
    final result = _findBestMatchWithConfidence(ingredientName, map);
    return result['key'];
  }

  /// Enhanced conversion method with confidence scoring
  Map<String, dynamic> convertWithConfidence({
    required double amount,
    required String fromUnit,
    required String toUnit,
    String ingredientName = '',
  }) {
    final String normFrom = _normalizeUnit(fromUnit);
    final String normTo = _normalizeUnit(toUnit);

    if (normFrom == normTo) {
      return {
        'amount': amount,
        'confidence': _highConfidence,
        'conversionPath': 'direct',
      };
    }

    double? amountInGrams;
    double? amountInMl;
    double? finalAmount;
    double overallConfidence = _highConfidence;
    String conversionPath = '';

    // --- Step 1: Convert initial amount to a base unit (grams or mL) ---

    // From Volume
    if (_volumeToMl.containsKey(normFrom)) {
      amountInMl = amount * _volumeToMl[normFrom]!;
      conversionPath += 'volume→ml';
    }
    // From Weight
    else if (_weightToGrams.containsKey(normFrom)) {
      amountInGrams = amount * _weightToGrams[normFrom]!;
      conversionPath += 'weight→g';
    }
    // From Piece (handles units like "clove", "large", "slice")
    else if (normFrom == 'piece' || normFrom == 'unit') {
      final pieceResult = _findBestMatchWithConfidence(ingredientName, _pieceToGrams);
      if (pieceResult['key'] != null) {
        amountInGrams = amount * _pieceToGrams[pieceResult['key']]!;
        overallConfidence = pieceResult['confidence'];
        conversionPath += 'piece→g';
      } else {
        // If no piece weight found, conversion fails
        return {
          'amount': amount,
          'confidence': 0.0,
          'conversionPath': 'failed',
        };
      }
    }
    // Handle special cases for very small amounts
    else if (normFrom == 'pinch' && normTo == 'teaspoon') {
      finalAmount = amount * 0.06; // 1 pinch ≈ 1/16 teaspoon
      overallConfidence = _lowConfidence;
      conversionPath = 'pinch→estimate';
    } else if (normFrom == 'dash' && normTo == 'teaspoon') {
      finalAmount = amount * 0.125; // 1 dash ≈ 1/8 teaspoon
      overallConfidence = _lowConfidence;
      conversionPath = 'dash→estimate';
    } else if (normFrom == 'splash' && normTo == 'teaspoon') {
      finalAmount = amount * 0.5; // 1 splash ≈ 1/2 teaspoon
      overallConfidence = _lowConfidence;
      conversionPath = 'splash→estimate';
    }
    // Unknown unit - fail conversion
    else {
      return {
        'amount': amount,
        'confidence': 0.0,
        'conversionPath': 'failed',
      };
    }

    // --- Step 2: Handle cross-conversions if necessary (e.g., g → mL) ---
    final densityResult = _findBestMatchWithConfidence(ingredientName, _ingredientDensities);
    final density = densityResult['key'] != null ? _ingredientDensities[densityResult['key']] : null;

    if (density != null) {
      if (amountInMl != null && amountInGrams == null) {
        // We have mL, can calculate grams
        amountInGrams = amountInMl * density;
        overallConfidence = (overallConfidence * densityResult['confidence']).clamp(0.0, 1.0);
        conversionPath += '→density→g';
      } else if (amountInGrams != null && amountInMl == null) {
        // We have grams, can calculate mL
        amountInMl = amountInGrams / density;
        overallConfidence = (overallConfidence * densityResult['confidence']).clamp(0.0, 1.0);
        conversionPath += '→density→ml';
      }
    } else {
      // If we need density but don't have it, and we can't convert directly, fail
      bool needsDensity = false;
      if (amountInMl != null && _weightToGrams.containsKey(normTo)) {
        needsDensity = true;
      } else if (amountInGrams != null && _volumeToMl.containsKey(normTo)) {
        needsDensity = true;
      }
      
      if (needsDensity) {
        return {
          'amount': amount,
          'confidence': 0.0,
          'conversionPath': 'failed',
        };
      }
    }

    // --- Step 3: Convert from base unit to target unit ---

    // To Volume
    if (_volumeToMl.containsKey(normTo)) {
      if (amountInMl != null) {
        finalAmount = amountInMl / _volumeToMl[normTo]!;
        conversionPath += '→' + normTo;
      }
    }
    // To Weight
    else if (_weightToGrams.containsKey(normTo)) {
      if (amountInGrams != null) {
        finalAmount = amountInGrams / _weightToGrams[normTo]!;
        conversionPath += '→' + normTo;
      }
    }
    // To Piece
    else if (normTo == 'piece' || normTo == 'unit') {
      final pieceResult = _findBestMatchWithConfidence(ingredientName, _pieceToGrams);
      if (pieceResult['key'] != null && amountInGrams != null) {
        finalAmount = amountInGrams / _pieceToGrams[pieceResult['key']]!;
        overallConfidence = (overallConfidence * pieceResult['confidence']).clamp(0.0, 1.0);
        conversionPath += '→piece';
      }
    }



    if (finalAmount != null) {
      return {
        'amount': finalAmount,
        'confidence': overallConfidence,
        'conversionPath': conversionPath,
      };
    }

    // If conversion is not possible, log it and return original amount with low confidence
    if (kDebugMode) {
      print(
          '⚠️ UnitConversionService: Cannot convert $amount from "$fromUnit" to "$toUnit" for ingredient "$ingredientName". No valid conversion path found.');
    }
    
    return {
      'amount': amount,
      'confidence': 0.0,
      'conversionPath': 'failed',
    };
  }

  /// Legacy conversion method for backward compatibility
  double convert({
    required double amount,
    required String fromUnit,
    required String toUnit,
    String ingredientName = '',
  }) {
    final result = convertWithConfidence(
      amount: amount,
      fromUnit: fromUnit,
      toUnit: toUnit,
      ingredientName: ingredientName,
    );
    return result['amount'];
  }

  /// Scales a list of ingredients by a given factor
  List<Map<String, dynamic>> scaleIngredients(
    List<Map<String, dynamic>> ingredients,
    double scaleFactor,
  ) {
    final scaledIngredients = <Map<String, dynamic>>[];
    
    for (final ingredient in ingredients) {
      final name = ingredient['name'] ?? '';
      final amount = (ingredient['amount'] ?? 0.0) as double;
      final unit = ingredient['unit'] ?? '';
      
      // Don't scale seasonings and spices beyond a certain threshold
      final isSeasoningOrSpice = _isSeasoningOrSpice(name);
      final adjustedScaleFactor = isSeasoningOrSpice && scaleFactor > 2.0 
          ? 1.0 + (scaleFactor - 1.0) * 0.5  // Reduce scaling for seasonings
          : scaleFactor;
      
      final scaledAmount = amount * adjustedScaleFactor;
      final optimized = optimizeUnits(scaledAmount, unit);
      
      scaledIngredients.add({
        ...ingredient,
        'amount': optimized['amount'],
        'unit': optimized['unit'],
        'originalAmount': amount,
        'originalUnit': unit,
        'scaleFactor': adjustedScaleFactor,
      });
    }
    
    return scaledIngredients;
  }

  /// Checks if an ingredient is a seasoning or spice
  bool _isSeasoningOrSpice(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    final seasonings = [
      'salt', 'pepper', 'paprika', 'cumin', 'oregano', 'basil', 'thyme', 
      'rosemary', 'cinnamon', 'nutmeg', 'ginger', 'turmeric', 'chili powder',
      'garlic powder', 'onion powder', 'bay leaf', 'parsley', 'cilantro',
      'dill', 'sage', 'marjoram', 'tarragon', 'mint', 'cardamom', 'cloves',
      'allspice', 'fennel', 'coriander', 'mustard seed', 'celery seed',
      'caraway', 'anise', 'vanilla', 'extract', 'seasoning', 'spice',
      'herb', 'powder', 'dried', 'ground'
    ];
    
    return seasonings.any((seasoning) => lowerName.contains(seasoning));
  }

  /// Enhanced unit optimization for human readability after scaling
  Map<String, dynamic> optimizeUnits(double amount, String unit) {
    String normUnit = _normalizeUnit(unit);

    // Handle count-based ingredients with smart fractional rounding
    final countBasedUnits = ['', 'whole', 'piece', 'pieces', 'item', 'items', 'unit', 'units'];
    if (countBasedUnits.contains(unit.toLowerCase())) {
      // Smart rounding for count-based items to nearest practical fraction
      if (amount <= 0.25) {
        return {'amount': 0.25, 'unit': unit}; // 1/4
      } else if (amount <= 0.375) {
        return {'amount': 0.5, 'unit': unit}; // 1/2
      } else if (amount <= 0.625) {
        return {'amount': 0.5, 'unit': unit}; // 1/2
      } else if (amount <= 0.875) {
        return {'amount': 0.75, 'unit': unit}; // 3/4
      } else if (amount < 1.25) {
        return {'amount': 1.0, 'unit': unit}; // 1
      } else if (amount < 1.75) {
        return {'amount': 1.5, 'unit': unit}; // 1 1/2
      } else if (amount < 2.25) {
        return {'amount': 2.0, 'unit': unit}; // 2
      } else {
        // For larger amounts, round to nearest half
        return {'amount': (amount * 2).round() / 2, 'unit': unit};
      }
    }

    // Volume optimizations
    if (normUnit == 'teaspoon' && amount >= 3) {
      return {'amount': amount / 3, 'unit': 'tablespoons'};
    } else if (normUnit == 'tablespoon' && amount >= 16) {
      return {'amount': amount / 16, 'unit': 'cups'};
    } else if (normUnit == 'cup' && amount < 0.25 && amount > 0) {
      return {'amount': amount * 16, 'unit': 'tablespoons'};
    } else if (normUnit == 'cup' && amount >= 16) {
      return {'amount': amount / 16, 'unit': 'gallons'};
    } else if (normUnit == 'ml' && amount >= 1000) {
      return {'amount': amount / 1000, 'unit': 'liters'};
    } else if (normUnit == 'liter' && amount < 0.25 && amount > 0) {
      return {'amount': amount * 1000, 'unit': 'ml'};
    }
    
    // Weight optimizations
    else if (normUnit == 'gram' && amount >= 1000) {
      return {'amount': amount / 1000, 'unit': 'kg'};
    } else if (normUnit == 'kilogram' && amount < 0.25 && amount > 0) {
      return {'amount': amount * 1000, 'unit': 'grams'};
    } else if (normUnit == 'ounce' && amount >= 16) {
      return {'amount': amount / 16, 'unit': 'pounds'};
    } else if (normUnit == 'pound' && amount < 0.25 && amount > 0) {
      return {'amount': amount * 16, 'unit': 'ounces'};
    }

    // No conversion needed, return original values
    return {'amount': amount, 'unit': unit};
  }

  /// Gets the canonical unit for a given unit type
  String getCanonicalUnit(String unit) {
    final normalized = _normalizeUnit(unit);
    
    if (_volumeToMl.containsKey(normalized)) {
      return 'ml';
    } else if (_weightToGrams.containsKey(normalized)) {
      return 'gram';
    } else if (normalized == 'piece' || normalized == 'unit') {
      return 'piece';
    }
    
    return normalized;
  }

  /// Checks if a conversion is possible between two units for a given ingredient
  bool canConvert({
    required String fromUnit,
    required String toUnit,
    String ingredientName = '',
  }) {
    final result = convertWithConfidence(
      amount: 1.0,
      fromUnit: fromUnit,
      toUnit: toUnit,
      ingredientName: ingredientName,
    );
    
    return result['confidence'] > 0.0;
  }

  /// Gets density for an ingredient if available
  double? getDensity(String ingredientName) {
    final result = _findBestMatchWithConfidence(ingredientName, _ingredientDensities);
    return result['key'] != null ? _ingredientDensities[result['key']] : null;
  }

  /// Gets piece weight for an ingredient if available
  double? getPieceWeight(String ingredientName) {
    final result = _findBestMatchWithConfidence(ingredientName, _pieceToGrams);
    return result['key'] != null ? _pieceToGrams[result['key']] : null;
  }

  /// Gets all available units for display in UI
  List<String> getAvailableUnits() {
    final units = <String>[];
    units.addAll(_volumeToMl.keys);
    units.addAll(_weightToGrams.keys);
    units.addAll(['piece', 'unit', 'serving', 'pinch', 'dash', 'splash']);
    return units..sort();
  }

  /// Gets common units for a specific ingredient category
  List<String> getCommonUnitsForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'liquids':
      case 'beverages':
        return ['cup', 'ml', 'liter', 'fluid ounce', 'tablespoon', 'teaspoon'];
      case 'dry ingredients':
      case 'flour':
      case 'sugar':
        return ['cup', 'gram', 'ounce', 'pound', 'tablespoon', 'teaspoon'];
      case 'meat':
      case 'protein':
        return ['piece', 'ounce', 'pound', 'gram', 'kilogram'];
      case 'vegetables':
      case 'fruits':
        return ['piece', 'cup', 'ounce', 'pound', 'gram'];
      case 'spices':
      case 'seasonings':
        return ['teaspoon', 'tablespoon', 'pinch', 'dash', 'gram', 'ounce'];
      default:
        return ['piece', 'cup', 'ounce', 'gram', 'tablespoon', 'teaspoon'];
    }
  }
}
