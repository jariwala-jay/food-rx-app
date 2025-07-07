// Test data containing real Spoonacular recipe search response
// This data can be used for testing recipe scaling, pantry deduction, and other services

class SpoonacularTestData {
  static const Map<String, dynamic> recipeSearchResponse = {
    "results": [
      {
        "id": 991010,
        "usedIngredientCount": 1,
        "missedIngredientCount": 4,
        "likes": 0,
        "missedIngredients": [
          {
            "id": 10211821,
            "amount": 0.5,
            "unit": "medium",
            "unitLong": "mediums",
            "unitShort": "medium",
            "aisle": "Produce",
            "name": "bell pepper",
            "original": "½ medium bell pepper (chopped)",
            "originalName": "bell pepper (chopped)",
            "meta": ["chopped", "()"],
            "image": "https://img.spoonacular.com/ingredients_100x100/bell-pepper-orange.png"
          },
          {
            "id": 18079,
            "amount": 0.5,
            "unit": "cup",
            "unitLong": "cups",
            "unitShort": "cup",
            "aisle": "Pasta and Rice",
            "name": "bread crumbs",
            "original": "½ cup bread crumbs",
            "originalName": "bread crumbs",
            "meta": [],
            "image": "https://img.spoonacular.com/ingredients_100x100/breadcrumbs.jpg"
          },
          {
            "id": 93733,
            "amount": 1,
            "unit": "packet",
            "unitLong": "packet",
            "unitShort": "pkt",
            "aisle": "Oil, Vinegar, Salad Dressing",
            "name": "ranch seasoning",
            "original": "1 packet Ranch seasoning",
            "originalName": "Ranch seasoning",
            "meta": [],
            "image": "https://img.spoonacular.com/ingredients_100x100/oregano-dried.png"
          },
          {
            "id": 1005114,
            "amount": 1,
            "unit": "lb",
            "unitLong": "pound",
            "unitShort": "lb",
            "aisle": "Meat",
            "name": "chicken",
            "original": "1 lb of lean shredded chicken",
            "originalName": "lean shredded chicken",
            "meta": ["shredded", "lean"],
            "extendedName": "lean shredded chicken",
            "image": "https://img.spoonacular.com/ingredients_100x100/rotisserie-chicken.png"
          }
        ],
        "usedIngredients": [
          {
            "id": 10011282,
            "amount": 0.5,
            "unit": "cup",
            "unitLong": "cups",
            "unitShort": "cup",
            "aisle": "Produce",
            "name": "purple onion",
            "original": "½ cup purple onion (chopped)",
            "originalName": "purple onion (chopped)",
            "meta": ["chopped", "()"],
            "image": "https://img.spoonacular.com/ingredients_100x100/red-onion.png"
          }
        ],
        "unusedIngredients": [
          {
            "id": 11252,
            "amount": 1,
            "unit": "serving",
            "unitLong": "serving",
            "unitShort": "serving",
            "aisle": "Produce",
            "name": "lettuce",
            "original": "lettuce",
            "originalName": "lettuce",
            "meta": [],
            "image": "https://img.spoonacular.com/ingredients_100x100/iceberg-lettuce.jpg"
          },
          {
            "id": 11529,
            "amount": 1,
            "unit": "serving",
            "unitLong": "serving",
            "unitShort": "serving",
            "aisle": "Produce",
            "name": "tomato",
            "original": "tomato",
            "originalName": "tomato",
            "meta": [],
            "image": "https://img.spoonacular.com/ingredients_100x100/tomato.png"
          }
        ],
        "title": "Chicken Ranch Burgers",
        "image": "https://img.spoonacular.com/recipes/991010-312x231.jpg",
        "imageType": "jpg",
        "calories": 365,
        "protein": "41g",
        "fat": "11g",
        "carbs": "20g"
      },
      {
        "id": 681713,
        "usedIngredientCount": 1,
        "missedIngredientCount": 6,
        "likes": 0,
        "missedIngredients": [
          {
            "id": 10023572,
            "amount": 1,
            "unit": "pound",
            "unitLong": "pound",
            "unitShort": "lb",
            "aisle": "Meat",
            "name": "ground beef",
            "original": "1 pound ground beef",
            "originalName": "ground beef",
            "meta": [],
            "image": "https://img.spoonacular.com/ingredients_100x100/fresh-ground-beef.jpg"
          },
          {
            "id": 10118408,
            "amount": 2,
            "unit": "Tablespoons",
            "unitLong": "Tablespoons",
            "unitShort": "Tbsp",
            "aisle": "Bakery/Bread",
            "name": "everything bagel spice blend",
            "original": "2 Tablespoons Everything Bagel Spice Blend",
            "originalName": "Everything Bagel Spice Blend",
            "meta": [],
            "image": "https://img.spoonacular.com/ingredients_100x100/sesame-bagel.jpg"
          }
        ],
        "usedIngredients": [
          {
            "id": 11252,
            "amount": 1,
            "unit": "slices",
            "unitLong": "slice",
            "unitShort": "slice",
            "aisle": "Produce",
            "name": "lettuce",
            "original": "lettuce, tomato slices, paper-thin red onion, and additional everything spice blend, for topping",
            "originalName": "lettuce, tomato paper-thin red onion, and additional everything spice blend, for topping",
            "meta": ["paper-thin", "red", "for topping "],
            "extendedName": "red paper-thin lettuce",
            "image": "https://img.spoonacular.com/ingredients_100x100/iceberg-lettuce.jpg"
          }
        ],
        "title": "Everything Bagel Cheese Burger",
        "image": "https://img.spoonacular.com/recipes/681713-312x231.png",
        "imageType": "png",
        "calories": 820,
        "protein": "42g",
        "fat": "37g",
        "carbs": "76g"
      },
      {
        "id": 632502,
        "usedIngredientCount": 2,
        "missedIngredientCount": 6,
        "likes": 0,
        "missedIngredients": [
          {
            "id": 9003,
            "amount": 1,
            "unit": "",
            "unitLong": "",
            "unitShort": "",
            "aisle": "Produce",
            "name": "apple",
            "original": "1 whole apple, diced",
            "originalName": "whole apple, diced",
            "meta": ["diced", "whole"],
            "extendedName": "whole diced apple",
            "image": "https://img.spoonacular.com/ingredients_100x100/apple.jpg"
          },
          {
            "id": 5662,
            "amount": 1,
            "unit": "pound",
            "unitLong": "pound",
            "unitShort": "lb",
            "aisle": "Meat",
            "name": "ground turkey",
            "original": "1 pound ground turkey (give or take 3 ounces depending on package weight)",
            "originalName": "ground turkey (give or take 3 ounces depending on package weight)",
            "meta": ["(give or take 3 ounces depending on package weight)"],
            "image": "https://img.spoonacular.com/ingredients_100x100/meat-ground.jpg"
          }
        ],
        "usedIngredients": [
          {
            "id": 11282,
            "amount": 0.25,
            "unit": "",
            "unitLong": "",
            "unitShort": "",
            "aisle": "Produce",
            "name": "onion",
            "original": "1/4 onion, finely chopped",
            "originalName": "onion, finely chopped",
            "meta": ["finely chopped"],
            "image": "https://img.spoonacular.com/ingredients_100x100/brown-onion.png"
          }
        ],
        "title": "Apple Cheddar Turkey Burgers With Chipotle Yogurt Sauce",
        "image": "https://img.spoonacular.com/recipes/632502-312x231.jpg",
        "imageType": "jpg",
        "calories": 362,
        "protein": "38g",
        "fat": "15g",
        "carbs": "19g"
      }
    ],
    "baseUri": "https://img.spoonacular.com/recipes/",
    "offset": 0,
    "number": 10,
    "totalResults": 7,
    "processingTimeMs": 737
  };

  // Helper method to get individual recipes for testing
  static Map<String, dynamic> getRecipeById(int id) {
    final results = recipeSearchResponse['results'] as List<dynamic>;
    return results.firstWhere(
      (recipe) => recipe['id'] == id,
      orElse: () => throw ArgumentError('Recipe with id $id not found'),
    ) as Map<String, dynamic>;
  }

  // Get all recipe IDs for iteration
  static List<int> getAllRecipeIds() {
    final results = recipeSearchResponse['results'] as List<dynamic>;
    return results.map((recipe) => recipe['id'] as int).toList();
  }

  // Convert search result ingredient to extended ingredient format for testing
  static Map<String, dynamic> convertToExtendedIngredient(Map<String, dynamic> ingredient) {
    final amount = (ingredient['amount'] as num).toDouble(); // Ensure double
    return {
      'id': ingredient['id'],
      'aisle': ingredient['aisle'],
      'image': ingredient['image'],
      'name': ingredient['name'],
      'amount': amount,
      'unit': ingredient['unit'] ?? '',
      'unitShort': ingredient['unitShort'] ?? '',
      'unitLong': ingredient['unitLong'] ?? '',
      'original': ingredient['original'] ?? '',
      'originalName': ingredient['originalName'] ?? '',
      'meta': ingredient['meta'] ?? [],
      'extendedName': ingredient['extendedName'],
      'measures': {
        'us': {
          'amount': amount,
          'unitShort': ingredient['unitShort'] ?? '',
          'unitLong': ingredient['unitLong'] ?? ''
        },
        'metric': {
          'amount': amount,
          'unitShort': ingredient['unitShort'] ?? '',
          'unitLong': ingredient['unitLong'] ?? ''
        }
      }
    };
  }

  // Create a mock recipe with extended ingredients for scaling tests
  static Map<String, dynamic> createMockRecipeForScaling(int recipeId) {
    final recipe = getRecipeById(recipeId);
    final allIngredients = [
      ...recipe['missedIngredients'] as List<dynamic>,
      ...recipe['usedIngredients'] as List<dynamic>,
    ];

    return {
      'id': recipe['id'],
      'title': recipe['title'],
      'image': recipe['image'],
      'servings': 4, // Default serving size
      'readyInMinutes': 30,
      'extendedIngredients': allIngredients
          .map((ingredient) => convertToExtendedIngredient(ingredient as Map<String, dynamic>))
          .toList(),
      'nutrition': {
        'nutrients': [
          {'name': 'Calories', 'amount': recipe['calories'], 'unit': 'kcal'},
          {'name': 'Protein', 'amount': recipe['protein'], 'unit': 'g'},
          {'name': 'Fat', 'amount': recipe['fat'], 'unit': 'g'},
          {'name': 'Carbohydrates', 'amount': recipe['carbs'], 'unit': 'g'},
        ]
      }
    };
  }
} 