// Constants for pantry categories
// Used in various pantry-related screens throughout the app

// Top-level FoodRx categories shown in Add FoodRx Items.
// Fruits / Vegetables open a group page with Fresh, Frozen, Canned (+ search).
const List<Map<String, String>> foodPantryCategories = [
  {
    'icon': 'assets/icons/food_pantry_icons/fresh_fruits.svg',
    'title': 'Fruits',
    'subtitle': 'Fresh, Frozen & Canned',
    'key': 'fruits',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/fresh_veggies.svg',
    'title': 'Vegetables',
    'subtitle': 'Fresh, Frozen & Canned',
    'key': 'vegetables',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/grains.svg',
    'title': 'Grains',
    'subtitle': 'Select up to 4',
    'key': 'grains',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/protein.svg',
    'title': 'Meat',
    'subtitle': 'Select up to 4',
    'key': 'meat',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/bean_soup.png',
    'title': 'Beans',
    'subtitle': 'Select up to 4',
    'key': 'beans',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/dairy.svg',
    'title': 'Dairy & Eggs',
    'subtitle': 'Select up to 4',
    'key': 'dairy',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/nuts.png',
    'title': 'Nuts',
    'subtitle': 'Select up to 2',
    'key': 'nuts_seeds',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/seasonings.svg',
    'title': 'Spices & Essentials',
    'subtitle': 'Select up to 2',
    'key': 'seasonings',
  },
  // 'miscellaneous' isn't selectable here — items land in it automatically
  // via resolveFoodRxCategoryForAisle and only surface through the Pantry
  // tab's category filter chips.
  // {
  //   'icon': 'assets/icons/food_pantry_icons/miscellaneous.png',
  //   'title': 'Miscellaneous',
  //   'subtitle': 'Other items',
  //   'key': 'miscellaneous',
  // },
];

/// Storage-type subcategories for Fruits and Vegetables group pages.
const Map<String, List<Map<String, String>>> foodPantrySubcategories = {
  'fruits': [
    {
      'icon': 'assets/icons/food_pantry_icons/fresh_fruits.svg',
      'title': 'Fresh',
      'subtitle': 'Select up to 4',
      'key': 'fresh_fruits',
    },
    {
      'icon': 'assets/icons/food_pantry_icons/frozen_berries.png',
      'title': 'Frozen',
      'subtitle': 'Select up to 2',
      'key': 'frozen_fruits',
    },
    {
      'icon': 'assets/icons/food_pantry_icons/canned_fruits.svg',
      'title': 'Canned',
      'subtitle': 'Select up to 2',
      'key': 'canned_fruits',
    },
  ],
  'vegetables': [
    {
      'icon': 'assets/icons/food_pantry_icons/fresh_veggies.svg',
      'title': 'Fresh',
      'subtitle': 'Select up to 6',
      'key': 'fresh_veggies',
    },
    {
      'icon': 'assets/icons/food_pantry_icons/frozen_veggies.png',
      'title': 'Frozen',
      'subtitle': 'Select up to 4',
      'key': 'frozen_veggies',
    },
    {
      'icon': 'assets/icons/food_pantry_icons/canned_veggies.svg',
      'title': 'Canned',
      'subtitle': 'Select up to 4',
      'key': 'canned_veggies',
    },
  ],
};

bool isFoodPantryGroupCategory(String categoryKey) =>
    foodPantrySubcategories.containsKey(categoryKey);

// "Other Pantry Items" (Add Home Items) categories — mirrors
// foodPantryCategories plus its own Snacks & Beverages.
const List<Map<String, String>> otherPantryItemCategories = [
  {
    'icon': 'assets/icons/food_pantry_icons/fresh_fruits.svg',
    'title': 'Fruits',
    'subtitle': 'Fresh, Frozen & Canned',
    'key': 'fruits',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/fresh_veggies.svg',
    'title': 'Vegetables',
    'subtitle': 'Fresh, Frozen & Canned',
    'key': 'vegetables',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/grains.svg',
    'title': 'Grains',
    'key': 'grains',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/protein.svg',
    'title': 'Meat',
    'key': 'meat',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/bean_soup.png',
    'title': 'Beans',
    'key': 'beans',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/dairy.svg',
    'title': 'Dairy & Eggs',
    'key': 'dairy',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/nuts.png',
    'title': 'Nuts',
    'key': 'nuts_seeds',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/seasonings.svg',
    'title': 'Spices & Essentials',
    'key': 'seasonings',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/snacks.svg',
    'title': 'Snacks & Beverages',
    'key': 'snacks_beverages',
  },
];

// Common pantry items for FoodRx (Food Pharmacy) categories
const Map<String, List<Map<String, dynamic>>> commonFoodPantryItems = {
  'fresh_fruits': [
    {
      'name': 'Apples',
      'id': 'apples',
      'spoonacularId': 9003,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/apple.jpg'
    },
    {
      'name': 'Strawberries',
      'id': 'strawberries',
      'spoonacularId': 9316,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strawberries.jpg'
    },
    {
      'name': 'Blueberries',
      'id': 'blueberries',
      'spoonacularId': 9050,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/blueberries.jpg'
    },
    {
      'name': 'Raspberries',
      'id': 'raspberries',
      'spoonacularId': 9302,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/raspberries.jpg'
    },
    {
      'name': 'Oranges',
      'id': 'oranges',
      'spoonacularId': 9200,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/orange.png'
    },
    {
      'name': 'Pears',
      'id': 'pears',
      'spoonacularId': 9252,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pears-bosc.jpg'
    },
    {
      'name': 'Grapefruit',
      'id': 'grapefruit',
      'spoonacularId': 9112,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/grapefruit.jpg'
    },
    {
      'name': 'Pomegranate',
      'id': 'pomegranate',
      'spoonacularId': 1009286,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pomegranate.jpg'
    },
    {
      'name': 'Avocado',
      'id': 'avocado',
      'spoonacularId': 9037,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/avocado.jpg'
    },
    {
      'name': 'Kiwi',
      'id': 'kiwi',
      'spoonacularId': 9148,
      'imageAsset': 'assets/pantry_ingredients/kiwi.jpg',
    },
    {
      'name': 'Bananas',
      'id': 'bananas',
      'spoonacularId': 9040,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bananas.jpg'
    },
    {
      'name': 'Grapes',
      'id': 'grapes',
      'spoonacularId': 9132,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/red-grapes.jpg'
    },
    {
      'name': 'Peaches',
      'id': 'peaches',
      'spoonacularId': 9236,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peach.png'
    },
    {
      'name': 'Plums',
      'id': 'plums',
      'spoonacularId': 9279,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/plum.jpg'
    },
    {
      'name': 'Clementines',
      'id': 'clementines',
      'spoonacularId': 9433,
      'imageAsset': 'assets/pantry_ingredients/clementines.jpg',
    },
    {
      'name': 'Watermelon',
      'id': 'watermelon',
      'spoonacularId': 9326,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/watermelon.jpg'
    },
    {
      'name': 'Cantaloupe',
      'id': 'cantaloupe',
      'spoonacularId': 9181,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cantaloupe.jpg'
    },
    {
      'name': 'Mango',
      'id': 'mango',
      'spoonacularId': 9176,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/mango.jpg'
    },
    {
      'name': 'Pineapple',
      'id': 'pineapple',
      'spoonacularId': 9266,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pineapple.jpg'
    },
    {
      'name': 'Lemons',
      'id': 'lemons',
      'spoonacularId': 9150,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/lemon.jpg'
    },
    {
      'name': 'Limes',
      'id': 'limes',
      'spoonacularId': 9159,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/lime.jpg'
    },
    {
      'name': 'Dates',
      'id': 'dates',
      'spoonacularId': 9087,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/dates.jpg'
    },
  ],
  'frozen_fruits': [
    {
      'name': 'Frozen Blueberries',
      'id': 'frozen-blueberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/blueberries.jpg'
    },
    {
      'name': 'Frozen Strawberries',
      'id': 'frozen-strawberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strawberries.jpg'
    },
    {
      'name': 'Frozen Mixed Berries',
      'id': 'frozen-mixed-berries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/berries-mixed.jpg'
    },
    {
      'name': 'Frozen Raspberries',
      'id': 'frozen-raspberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/raspberries.jpg'
    },
    {
      'name': 'Frozen Blackberries',
      'id': 'frozen-blackberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/blackberries.jpg'
    },
    {
      'name': 'Frozen Cherries',
      'id': 'frozen-cherries',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cherries.jpg'
    },
    {
      'name': 'Frozen Mango',
      'id': 'frozen-mango',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/mango.jpg'
    },
    {
      'name': 'Frozen Peaches',
      'id': 'frozen-peaches',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peach.png'
    },
    {
      'name': 'Frozen Pineapple',
      'id': 'frozen-pineapple',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pineapple.jpg'
    },
  ],
  'canned_fruits': [
    {
      'name': 'Applesauce',
      'id': 'applesauce',
      'spoonacularId': 9019,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/applesauce.jpg'
    },
    {
      'name': 'Canned Peaches',
      'id': 'canned-peaches',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peach.png'
    },
    {
      'name': 'Canned Pears',
      'id': 'canned-pears',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pears-bosc.jpg'
    },
    {
      'name': 'Canned Mandarin Oranges',
      'id': 'canned-mandarin',
      'spoonacularId': 9383,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/orange.png'
    },
    {
      'name': 'Canned Pineapple',
      'id': 'canned-pineapple',
      'spoonacularId': 9354,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pineapple.jpg'
    },
    {
      'name': 'Canned Cherries',
      'id': 'canned-cherries',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cherries.jpg'
    },
    {
      'name': 'Canned Apricots',
      'id': 'canned-apricots',
      'imageAsset': 'assets/pantry_ingredients/canned_apricots.jpg',
    },
    {
      'name': 'Fruit Cocktail',
      'id': 'fruit-cocktail',
      'spoonacularId': 9099,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/fruit-cocktail.jpg'
    },
  ],
  'fresh_veggies': [
    {
      'name': 'Spinach',
      'id': 'spinach',
      'spoonacularId': 10011457,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/spinach.jpg'
    },
    {
      'name': 'Broccoli',
      'id': 'broccoli',
      'spoonacularId': 11090,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/broccoli.jpg'
    },
    {
      'name': 'Carrots',
      'id': 'carrots',
      'spoonacularId': 11124,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/carrots.jpg'
    },
    {
      'name': 'Tomatoes',
      'id': 'tomatoes',
      'spoonacularId': 11529,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tomato.png'
    },
    {
      'name': 'Bell Peppers',
      'id': 'bell-peppers',
      'spoonacularId': 10211821,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/green-pepper.jpg'
    },
    {
      'name': 'Onions',
      'id': 'onions',
      'spoonacularId': 11282,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brown-onion.png'
    },
    {
      'name': 'Garlic',
      'id': 'garlic',
      'spoonacularId': 11215,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/garlic.jpg'
    },
    {
      'name': 'Cucumber',
      'id': 'cucumber',
      'spoonacularId': 11206,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cucumber.jpg'
    },
    {
      'name': 'Zucchini',
      'id': 'zucchini',
      'spoonacularId': 11477,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/zucchini.jpg'
    },
    {
      'name': 'Cauliflower',
      'id': 'cauliflower',
      'spoonacularId': 11135,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cauliflower.jpg'
    },
    {
      'name': 'Green Beans',
      'id': 'green-beans',
      'spoonacularId': 11052,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/green-beans-or-string-beans.jpg'
    },
    {
      'name': 'Sweet Potatoes',
      'id': 'sweet-potatoes',
      'spoonacularId': 11507,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sweet-potato.jpg'
    },
    {
      'name': 'Kale',
      'id': 'kale',
      'spoonacularId': 11233,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/kale.jpg'
    },
    {
      'name': 'Romaine Lettuce',
      'id': 'romaine-lettuce',
      'spoonacularId': 10111251,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/romaine.jpg'
    },
    {
      'name': 'Lettuce',
      'id': 'lettuce',
      'spoonacularId': 11252,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/iceberg-lettuce.jpg'
    },
    {
      'name': 'Collard Greens',
      'id': 'collard-greens',
      'spoonacularId': 11161,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/collard-greens.jpg'
    },
    {
      'name': 'Swiss Chard',
      'id': 'swiss-chard',
      'spoonacularId': 11147,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/swiss-chard.jpg'
    },
    {
      'name': 'Brussels Sprouts',
      'id': 'brussels-sprouts',
      'spoonacularId': 11098,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brussels-sprouts.jpg'
    },
    {
      'name': 'Asparagus',
      'id': 'asparagus',
      'spoonacularId': 11011,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/asparagus.jpg'
    },
    {
      'name': 'Cabbage',
      'id': 'cabbage',
      'spoonacularId': 11109,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cabbage.jpg'
    },
    {
      'name': 'Mushrooms',
      'id': 'mushrooms',
      'spoonacularId': 11260,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mushrooms.jpg'
    },
    {
      'name': 'Celery',
      'id': 'celery',
      'spoonacularId': 11143,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/celery.jpg'
    },
    {
      'name': 'Eggplant',
      'id': 'eggplant',
      'spoonacularId': 11209,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/eggplant.jpg'
    },
    {
      'name': 'Butternut Squash',
      'id': 'butternut-squash',
      'spoonacularId': 11485,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/butternut-squash.jpg'
    },
    {
      'name': 'Potatoes',
      'id': 'potatoes',
      'spoonacularId': 11352,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/potatoes-yukon-gold.jpg'
    },
    {
      'name': 'Corn',
      'id': 'corn',
      'spoonacularId': 11168,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/corn.jpg'
    },
    {
      'name': 'Peas',
      'id': 'peas',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peas.jpg'
    },
    {
      'name': 'Okra',
      'id': 'okra',
      'spoonacularId': 11278,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/okra.png'
    },
    {
      'name': 'Beets',
      'id': 'beets',
      'spoonacularId': 11080,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/beets.jpg'
    },
    {
      'name': 'Radishes',
      'id': 'radishes',
      'spoonacularId': 11429,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/radishes.jpg'
    },
    {
      'name': 'Turnips',
      'id': 'turnips',
      'spoonacularId': 11564,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/turnips.jpg'
    },
    {
      'name': 'Parsnips',
      'id': 'parsnips',
      'spoonacularId': 11298,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parsnip.jpg'
    },
    {
      'name': 'Leeks',
      'id': 'leeks',
      'spoonacularId': 11246,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/leeks.jpg'
    },
    {
      'name': 'Ginger',
      'id': 'ginger',
      'spoonacularId': 11216,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ginger.jpg'
    },
    {
      'name': 'Chili Peppers',
      'id': 'chili-peppers',
      'spoonacularId': 11819,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/red-chili.jpg'
    },
    {
      'name': 'Jalapeno',
      'id': 'jalapeno',
      'spoonacularId': 11979,
      'imageAsset': 'assets/pantry_ingredients/jalapeno.jpg',
    },
  ],
  'frozen_veggies': [
    {
      'name': 'Frozen Broccoli',
      'id': 'frozen-broccoli',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/broccoli.jpg'
    },
    {
      'name': 'Frozen Spinach',
      'id': 'frozen-spinach',
      'spoonacularId': 11463,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/spinach.jpg'
    },
    {
      'name': 'Frozen Mixed Vegetables',
      'id': 'frozen-mixed-vegetables',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mixed-vegetables.jpg'
    },
    {
      'name': 'Frozen Green Beans',
      'id': 'frozen-green-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/green-beans-or-string-beans.jpg'
    },
    {
      'name': 'Frozen Cauliflower',
      'id': 'frozen-cauliflower',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cauliflower.jpg'
    },
    {
      'name': 'Frozen Peas',
      'id': 'frozen-peas',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peas.jpg'
    },
    {
      'name': 'Frozen Carrots',
      'id': 'frozen-carrots',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/carrots.jpg'
    },
    {
      'name': 'Frozen Brussels Sprouts',
      'id': 'frozen-brussels-sprouts',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brussels-sprouts.jpg'
    },
    {
      'name': 'Frozen Corn',
      'id': 'frozen-corn',
      'spoonacularId': 11913,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/corn.jpg'
    },
  ],
  'canned_veggies': [
    {
      'name': 'Canned Tomatoes',
      'id': 'canned-tomatoes',
      'spoonacularId': 10011693,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tomato.png'
    },
    {
      'name': 'Tomato Sauce',
      'id': 'tomato-sauce',
      'spoonacularId': 11549,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/tomato-sauce-or-pasta-sauce.jpg'
    },
    {
      'name': 'Tomato Paste',
      'id': 'tomato-paste',
      'spoonacularId': 11887,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/tomato-paste.jpg'
    },
    {
      'name': 'Canned Spinach',
      'id': 'canned-spinach',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/spinach.jpg'
    },
    {
      'name': 'Canned Green Beans',
      'id': 'canned-green-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/green-beans-or-string-beans.jpg'
    },
    {
      'name': 'Canned Peas',
      'id': 'canned-peas',
      'spoonacularId': 11306,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peas.jpg'
    },
    {
      'name': 'Canned Corn',
      'id': 'canned-corn',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/corn.jpg'
    },
    {
      'name': 'Canned Carrots',
      'id': 'canned-carrots',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/carrots.jpg'
    },
    {
      'name': 'Canned Mixed Vegetables',
      'id': 'canned-mixed-vegetables',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mixed-vegetables.jpg'
    },
    {
      'name': 'Canned Beets',
      'id': 'canned-beets',
      'spoonacularId': 11609,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/beets.jpg'
    },
    {
      'name': 'Canned Mushrooms',
      'id': 'canned-mushrooms',
      'spoonacularId': 11264,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mushrooms.jpg'
    },
  ],
  'grains': [
    {
      'name': 'White Rice',
      'id': 'white-rice',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/uncooked-white-rice.png'
    },
    {
      'name': 'Brown Rice',
      'id': 'brown-rice',
      'spoonacularId': 20040,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/uncooked-brown-rice.png'
    },
    {
      'name': 'Rice Noodles',
      'id': 'rice-noodles',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/rice-noodles.jpg'
    },
    {
      'name': 'Bread',
      'id': 'bread',
      'spoonacularId': 18064,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-bread.jpg'
    },
    {
      'name': 'Whole Wheat Bread',
      'id': 'whole-wheat-bread',
      'spoonacularId': 18075,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/whole-wheat-bread.jpg'
    },
    {
      'name': 'Pasta',
      'id': 'pasta',
      'spoonacularId': 20420,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/fusilli.jpg'
    },
    {
      'name': 'Whole Wheat Pasta',
      'id': 'whole-wheat-pasta',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/whole-wheat-spaghetti.jpg'
    },
    {
      'name': 'Spaghetti',
      'id': 'spaghetti',
      'spoonacularId': 11420420,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/spaghetti.jpg'
    },
    {
      'name': 'Tortillas',
      'id': 'tortillas',
      'spoonacularId': 18364,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/flour-tortilla.jpg'
    },
    {
      'name': 'Whole Wheat Flour',
      'id': 'whole-wheat-flour',
      'spoonacularId': 20080,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/flour.png'
    },
    {
      'name': 'Oats',
      'id': 'oats',
      'spoonacularId': 8120,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/rolled-oats.jpg'
    },
    {
      'name': 'Steel Cut Oats',
      'id': 'steel-cut-oats',
      'spoonacularId': 93695,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/steel-cut-oats.png'
    },
    {
      'name': 'Quinoa',
      'id': 'quinoa',
      'spoonacularId': 20035,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/quinoa.jpg'
    },
    {
      'name': 'Barley',
      'id': 'barley',
      'spoonacularId': 20004,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pearl-barley.png'
    },
    {
      'name': 'Farro',
      'id': 'farro',
      'spoonacularId': 10020005,
      'imageAsset': 'assets/pantry_ingredients/farro.jpg',
    },
    {
      'name': 'Bulgur',
      'id': 'bulgur',
      'spoonacularId': 20012,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bulgur.jpg'
    },
    {
      'name': 'Couscous',
      'id': 'couscous',
      'spoonacularId': 20028,
      'imageAsset': 'assets/pantry_ingredients/couscous.jpg'
    },
    {
      'name': 'Cereal',
      'id': 'cereal',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cheerios.jpg'
    },
    {
      'name': 'Cornmeal',
      'id': 'cornmeal',
      'spoonacularId': 35137,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cornmeal.jpg'
    },
  ],
  'meat': [
    {
      'name': 'Chicken Breast',
      'id': 'chicken-breast',
      'spoonacularId': 5062,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chicken-breasts.jpg'
    },
    {
      'name': 'Chicken Thighs',
      'id': 'chicken-thighs',
      'spoonacularId': 5096,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chicken-thighs.jpg'
    },
    {
      'name': 'Ground Chicken',
      'id': 'ground-chicken',
      'spoonacularId': 5332,
      'imageAsset': 'assets/pantry_ingredients/ground_chicken.jpg',
    },
    {
      'name': 'Canned Chicken',
      'id': 'canned-chicken',
      'spoonacularId': 5311,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/rotisserie-chicken.jpg'
    },
    {
      'name': 'Turkey Breast',
      'id': 'turkey-breast',
      'spoonacularId': 5696,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/turkey-breast.jpg'
    },
    {
      'name': 'Ground Turkey',
      'id': 'ground-turkey',
      'spoonacularId': 5662,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/meat-ground.jpg'
    },
    {
      'name': 'Salmon Fillet',
      'id': 'salmon-fillet',
      'spoonacularId': 10115076,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salmon.jpg'
    },
    {
      'name': 'Canned Salmon',
      'id': 'canned-salmon',
      'spoonacularId': 15260,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salmon.jpg'
    },
    {
      'name': 'Tilapia',
      'id': 'tilapia',
      'spoonacularId': 15261,
      'imageAsset': 'assets/pantry_ingredients/tilapia.jpg',
    },
    {
      'name': 'Cod',
      'id': 'cod',
      'spoonacularId': 15015,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cod-fillet.jpg'
    },
    {
      'name': 'Shrimp',
      'id': 'shrimp',
      'spoonacularId': 15270,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/shrimp.jpg'
    },
    {
      'name': 'Canned Tuna',
      'id': 'canned-tuna',
      'spoonacularId': 10115121,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/canned-tuna.png'
    },
    {
      'name': 'Ground Beef',
      'id': 'ground-beef',
      'spoonacularId': 10123572,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/beef-brisket.jpg'
    },
    {
      'name': 'Beef Steak',
      'id': 'beef-steak',
      'spoonacularId': 23232,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strip-steak.jpg'
    },
    {
      'name': 'Pork Chops',
      'id': 'pork-chops',
      'spoonacularId': 10010062,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pork-chops.jpg'
    },
    {
      'name': 'Ham',
      'id': 'ham',
      'spoonacularId': 10151,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ham.jpg'
    },
    {
      'name': 'Bacon',
      'id': 'bacon',
      'spoonacularId': 99006,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bacon.jpg'
    },
    {
      'name': 'Tofu',
      'id': 'tofu',
      'spoonacularId': 16213,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tofu.jpg'
    },
    {
      'name': 'Tempeh',
      'id': 'tempeh',
      'spoonacularId': 16114,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tempeh.jpg'
    },
  ],
  'beans': [
    {
      'name': 'Black Beans',
      'id': 'black-beans',
      'spoonacularId': 16015,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/black-beans.jpg'
    },
    {
      'name': 'Chickpeas',
      'id': 'chickpeas',
      'spoonacularId': 16057,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chickpeas.jpg'
    },
    {
      'name': 'Kidney Beans',
      'id': 'kidney-beans',
      'spoonacularId': 16033,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/kidney-beans.jpg'
    },
    {
      'name': 'Pinto Beans',
      'id': 'pinto-beans',
      'spoonacularId': 16043,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pinto-beans.jpg'
    },
    {
      'name': 'White Beans',
      'id': 'white-beans',
      'spoonacularId': 10516050,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-beans.jpg'
    },
    {
      'name': 'Cannellini Beans',
      'id': 'cannellini-beans',
      'spoonacularId': 10716050,
      'imageAsset': 'assets/pantry_ingredients/cannellini_beans.jpg',
    },
    {
      'name': 'Navy Beans',
      'id': 'navy-beans',
      'spoonacularId': 16038,
      'imageAsset': 'assets/pantry_ingredients/navy_beans.jpg',
    },
    {
      'name': 'Lentils',
      'id': 'lentils',
      'spoonacularId': 10316069,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/lentils-brown.jpg'
    },
    {
      'name': 'Split Peas',
      'id': 'split-peas',
      'spoonacularId': 16085,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/split-peas-green.jpg'
    },
    {
      'name': 'Black Eyed Peas',
      'id': 'black-eyed-peas',
      'spoonacularId': 16063,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/black-eyed-peas.jpg'
    },
  ],
  'dairy': [
    {
      'name': 'Milk',
      'id': 'milk',
      'spoonacularId': 1077,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/milk.jpg'
    },
    {
      'name': 'Low Fat Milk',
      'id': 'low-fat-milk',
      'spoonacularId': 1082,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/milk.jpg'
    },
    {
      'name': 'Almond Milk',
      'id': 'almond-milk',
      'spoonacularId': 93607,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/almond-milk.jpg'
    },
    {
      'name': 'Half and Half',
      'id': 'half-and-half',
      'spoonacularId': 1049,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/milk.jpg'
    },
    {
      'name': 'Heavy Cream',
      'id': 'heavy-cream',
      'imageAsset': 'assets/pantry_ingredients/heavy_cream.png',
    },
    {
      'name': 'Buttermilk',
      'id': 'buttermilk',
      'spoonacularId': 1230,
      'imageAsset': 'assets/pantry_ingredients/buttermilk.png',
    },
    {
      'name': 'Powdered Milk',
      'id': 'powdered-milk',
      'spoonacularId': 1090,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/milk-powdered.jpg'
    },
    {
      'name': 'Evaporated Milk',
      'id': 'evaporated-milk',
      'spoonacularId': 1214,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/evaporated-milk.png'
    },
    {
      'name': 'Yogurt',
      'id': 'yogurt',
      'spoonacularId': 1116,
      'imageAsset': 'assets/pantry_ingredients/yogurt.jpg',
    },
    {
      'name': 'Greek Yogurt',
      'id': 'greek-yogurt',
      'spoonacularId': 1256,
      'imageAsset': 'assets/pantry_ingredients/greek_yogurt.jpg',
    },
    {
      'name': 'Cheese',
      'id': 'cheese',
      'spoonacularId': 1041009,
      'imageAsset': 'assets/pantry_ingredients/cheese.jpg',
    },
    {
      'name': 'Cottage Cheese',
      'id': 'cottage-cheese',
      'spoonacularId': 1012,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cottage-cheese.jpg'
    },
    {
      'name': 'Cream Cheese',
      'id': 'cream-cheese',
      'spoonacularId': 1017,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cream-cheese.jpg'
    },
    {
      'name': 'Mozzarella Cheese',
      'id': 'mozzarella',
      'spoonacularId': 1026,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mozzarella-balls.jpg'
    },
    {
      'name': 'Parmesan Cheese',
      'id': 'parmesan',
      'spoonacularId': 1033,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parmesan.jpg'
    },
    {
      'name': 'Swiss Cheese',
      'id': 'swiss-cheese',
      'spoonacularId': 1040,
      'imageAsset': 'assets/pantry_ingredients/swiss_cheese.jpg'
    },
    {
      'name': 'Ricotta Cheese',
      'id': 'ricotta',
      'spoonacularId': 1036,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ricotta-cheese.jpg'
    },
    {
      'name': 'Feta Cheese',
      'id': 'feta',
      'spoonacularId': 1019,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/feta-cheese.jpg'
    },
    {
      'name': 'Butter',
      'id': 'butter',
      'spoonacularId': 1001,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/butter-sliced.jpg'
    },
    {
      'name': 'Sour Cream',
      'id': 'sour-cream',
      'spoonacularId': 1056,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sour-cream.jpg'
    },
    {
      'name': 'Eggs',
      'id': 'eggs',
      'spoonacularId': 1123,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/egg.jpg'
    },
    {
      'name': 'Egg Whites',
      'id': 'egg-whites',
      'spoonacularId': 1124,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/egg-white.jpg'
    },
  ],
  'nuts_seeds': [
    {
      'name': 'Almonds',
      'id': 'almonds',
      'spoonacularId': 12061,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/almonds.jpg'
    },
    {
      'name': 'Walnuts',
      'id': 'walnuts',
      'spoonacularId': 12155,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/walnuts.jpg'
    },
    {
      'name': 'Peanuts',
      'id': 'peanuts',
      'spoonacularId': 16091,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peanuts.png'
    },
    {
      'name': 'Cashews',
      'id': 'cashews',
      'spoonacularId': 12087,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cashews.jpg'
    },
    {
      'name': 'Pistachios',
      'id': 'pistachios',
      'spoonacularId': 12151,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pistachios.jpg'
    },
    {
      'name': 'Pecans',
      'id': 'pecans',
      'spoonacularId': 12142,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/pecans.jpg'
    },
    {
      'name': 'Mixed Nuts',
      'id': 'mixed-nuts',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/nuts-mixed.jpg'
    },
    {
      'name': 'Peanut Butter',
      'id': 'peanut-butter',
      'spoonacularId': 16098,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/peanut-butter.jpg'
    },
    {
      'name': 'Almond Butter',
      'id': 'almond-butter',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/almond-butter.jpg'
    },
    {
      'name': 'Chia Seeds',
      'id': 'chia-seeds',
      'spoonacularId': 12006,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chia-seeds.jpg'
    },
    {
      'name': 'Flax Seeds',
      'id': 'flax-seeds',
      'spoonacularId': 10012220,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/flax-seeds.png'
    },
    {
      'name': 'Sunflower Seeds',
      'id': 'sunflower-seeds',
      'spoonacularId': 12036,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sunflower-seeds.jpg'
    },
    {
      'name': 'Pumpkin Seeds',
      'id': 'pumpkin-seeds',
      'spoonacularId': 12014,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pumpkin-seeds.jpg'
    },
    {
      'name': 'Sesame Seeds',
      'id': 'sesame-seeds',
      'spoonacularId': 12023,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sesame-seeds.jpg'
    },
    {
      'name': 'Hemp Seeds',
      'id': 'hemp-seeds',
      'spoonacularId': 93602,
      'imageAsset': 'assets/pantry_ingredients/hemp_hearts.jpg',
    },
  ],
  'seasonings': [
    {
      'name': 'Salt',
      'id': 'salt',
      'spoonacularId': 2047,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salt.jpg'
    },
    {
      'name': 'Black Pepper',
      'id': 'black-pepper',
      'spoonacularId': 1002030,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/pepper.jpg'
    },
    {
      'name': 'Garlic Powder',
      'id': 'garlic-powder',
      'spoonacularId': 1022020,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/garlic-powder.jpg'
    },
    {
      'name': 'Onion Powder',
      'id': 'onion-powder',
      'spoonacularId': 2026,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/onion-powder.jpg'
    },
    {
      'name': 'Paprika',
      'id': 'paprika',
      'spoonacularId': 2028,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/paprika.jpg'
    },
    {
      'name': 'Chili Powder',
      'id': 'chili-powder',
      'spoonacularId': 2009,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chili-powder.jpg'
    },
    {
      'name': 'Red Pepper Flakes',
      'id': 'red-pepper-flakes',
      'spoonacularId': 1032009,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/red-pepper-flakes.jpg'
    },
    {
      'name': 'Ground Cayenne Pepper',
      'id': 'ground-cayenne-pepper',
      'spoonacularId': 2031,
      'imageAsset': 'assets/pantry_ingredients/ground_cayenne_pepper.jpg',
    },
    {
      'name': 'Turmeric',
      'id': 'turmeric',
      'spoonacularId': 2043,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/turmeric.jpg'
    },
    {
      'name': 'Ginger Powder',
      'id': 'ginger-powder',
      'spoonacularId': 2021,
      'imageAsset': 'assets/pantry_ingredients/ginger_powder.jpg',
    },
    {
      'name': 'Cumin',
      'id': 'cumin',
      'spoonacularId': 1002014,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ground-cumin.jpg'
    },
    {
      'name': 'Curry Powder',
      'id': 'curry-powder',
      'spoonacularId': 2015,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/curry-powder.jpg'
    },
    {
      'name': 'Oregano',
      'id': 'oregano',
      'spoonacularId': 2027,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/oregano.jpg'
    },
    {
      'name': 'Basil',
      'id': 'basil',
      'spoonacularId': 2003,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/basil.jpg'
    },
    {
      'name': 'Thyme',
      'id': 'thyme',
      'spoonacularId': 2049,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/thyme.jpg'
    },
    {
      'name': 'Bay Leaves',
      'id': 'bay-leaves',
      'spoonacularId': 2004,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/bay-leaves.jpg'
    },
    {
      'name': 'Italian Seasoning',
      'id': 'italian-seasoning',
      'spoonacularId': 1022027,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dried-herbs.png'
    },
    {
      'name': 'Cinnamon',
      'id': 'cinnamon',
      'spoonacularId': 2010,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cinnamon.jpg'
    },
    {
      'name': 'Nutmeg',
      'id': 'nutmeg',
      'spoonacularId': 2025,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/nutmeg.jpg'
    },
    {
      'name': 'Parsley',
      'id': 'parsley',
      'spoonacularId': 11297,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parsley.jpg'
    },
    {
      'name': 'Cilantro',
      'id': 'cilantro',
      'spoonacularId': 11165,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cilantro.jpg'
    },
    {
      'name': 'Olive Oil',
      'id': 'olive-oil',
      'spoonacularId': 4053,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/olive-oil.jpg'
    },
    {
      'name': 'Vegetable Oil',
      'id': 'vegetable-oil',
      'spoonacularId': 4669,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/vegetable-oil.jpg'
    },
    {
      'name': 'Coconut Oil',
      'id': 'coconut-oil',
      'spoonacularId': 4047,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/coconut-oil.jpg'
    },
    {
      'name': 'Sesame Oil',
      'id': 'sesame-oil',
      'spoonacularId': 4058,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sesame-oil.jpg'
    },
    {
      'name': 'Vinegar',
      'id': 'vinegar',
      'spoonacularId': 2053,
      'imageAsset': 'assets/pantry_ingredients/vinegar.png',
    },
    {
      'name': 'Apple Cider Vinegar',
      'id': 'apple-cider-vinegar',
      'spoonacularId': 2048,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/apple-cider-vinegar.jpg'
    },
    {
      'name': 'Balsamic Vinegar',
      'id': 'balsamic-vinegar',
      'spoonacularId': 2069,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/balsamic-vinegar.jpg'
    },
    {
      'name': 'Distilled White Vinegar',
      'id': 'distilled-white-vinegar',
      'spoonacularId': 2053,
      'imageAsset': 'assets/pantry_ingredients/distilled_white_vinegar.png',
    },
    {
      'name': 'Baking Powder',
      'id': 'baking-powder',
      'spoonacularId': 18369,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-powder.jpg'
    },
    {
      'name': 'Baking Soda',
      'id': 'baking-soda',
      'spoonacularId': 18372,
      'imageAsset': 'assets/pantry_ingredients/baking_soda.png',
    },
    {
      'name': 'Vanilla Extract',
      'id': 'vanilla-extract',
      'spoonacularId': 2050,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/vanilla-extract.jpg'
    },
    {
      'name': 'Sugar',
      'id': 'sugar',
      'spoonacularId': 19335,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sugar-in-bowl.jpg'
    },
    {
      'name': 'Brown Sugar',
      'id': 'brown-sugar',
      'spoonacularId': 19334,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/light-brown-sugar.jpg'
    },
    {
      'name': 'Honey',
      'id': 'honey',
      'spoonacularId': 19296,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/honey.jpg'
    },
    {
      'name': 'Maple Syrup',
      'id': 'maple-syrup',
      'spoonacularId': 19911,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/maple-syrup.png'
    },
    {
      'name': 'Jam/Jelly',
      'id': 'jam',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strawberry-jam.jpg'
    },
    {
      'name': 'Soy Sauce',
      'id': 'soy-sauce',
      'spoonacularId': 16124,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/soy-sauce.jpg'
    },
    {
      'name': 'Worcestershire Sauce',
      'id': 'worcestershire',
      'spoonacularId': 6971,
      'imageAsset': 'assets/pantry_ingredients/worcestershire_sauce.png',
    },
    {
      'name': 'Hot Sauce',
      'id': 'hot-sauce',
      'spoonacularId': 6168,
      'imageAsset': 'assets/pantry_ingredients/hot_sauce.png',
    },
    {
      'name': 'Ketchup',
      'id': 'ketchup',
      'spoonacularId': 11935,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ketchup.jpg'
    },
    {
      'name': 'Mustard',
      'id': 'mustard',
      'spoonacularId': 2046,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dijon-mustard.jpg'
    },
    {
      'name': 'Mayonnaise',
      'id': 'mayonnaise',
      'spoonacularId': 4025,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mayonnaise.jpg'
    },
    {
      'name': 'Salad Dressing',
      'id': 'salad-dressing',
      'spoonacularId': 4114,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ranch-dressing.jpg'
    },
    {
      'name': 'BBQ Sauce',
      'id': 'bbq-sauce',
      'spoonacularId': 6150,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/barbecue-sauce.jpg'
    },
    {
      'name': 'Pasta Sauce',
      'id': 'pasta-sauce',
      'spoonacularId': 10011549,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/tomato-paste.jpg'
    },
    {
      'name': 'Salsa',
      'id': 'salsa',
      'spoonacularId': 6164,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salsa.jpg'
    },
    {
      'name': 'Pickles',
      'id': 'pickles',
      'spoonacularId': 11937,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dill-pickles.jpg'
    },
    {
      'name': 'Relish',
      'id': 'relish',
      'spoonacularId': 11944,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pickle-relish.jpg'
    },
  ],
};

// Common pantry items for Other Pantry categories
const Map<String, List<Map<String, dynamic>>> commonOtherPantryItems = {
  'snacks_beverages': [
    {
      'name': 'Chips',
      'id': 'chips',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/potato-chips.jpg'
    },
    {
      'name': 'Cookies',
      'id': 'cookies',
      'spoonacularId': 10118192,
      'imageAsset': 'assets/pantry_ingredients/cookies.png',
    },
    {
      'name': 'Granola Bars',
      'id': 'granola-bars',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/granola.jpg'
    },
    {
      'name': 'Pretzels',
      'id': 'pretzels',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/pretzels.jpg'
    },
    {
      'name': 'Popcorn',
      'id': 'popcorn',
      'spoonacularId': 19034,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/popcorn.jpg'
    },
    {
      'name': 'Coffee',
      'id': 'coffee',
      'spoonacularId': 14209,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brewed-coffee.jpg'
    },
    {
      'name': 'Tea',
      'id': 'tea',
      'spoonacularId': 14355,
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tea-bags.jpg'
    },
    {
      'name': 'Juice',
      'id': 'juice',
      'spoonacularId': 1019016,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/orange-juice.jpg'
    },
    {
      'name': 'Soda',
      'id': 'soda',
      'imageAsset': 'assets/pantry_ingredients/soda.png',
    },
    {
      'name': 'Energy Drinks',
      'id': 'energy-drinks',
      'imageAsset': 'assets/pantry_ingredients/energy_drinks.png',
    },
    {
      'name': 'Sparkling Water',
      'id': 'sparkling-water',
      'spoonacularId': 14121,
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sparkling-water.png'
    },
    {
      'name': 'Trail Mix',
      'id': 'trail-mix',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/trail-mix.jpg'
    },
  ],
};

// Helper function to get common items for a category.
// Home Items (isFoodPantryItem == false) shares FoodRx's item lists for every
// category except Snacks & Beverages, which is Home-only.
List<Map<String, dynamic>> getCommonItemsForCategory(
    String categoryKey, bool isFoodPantryItem) {
  if (isFoodPantryItem) {
    return commonFoodPantryItems[categoryKey] ?? [];
  } else {
    return commonOtherPantryItems[categoryKey] ??
        commonFoodPantryItems[categoryKey] ??
        [];
  }
}

/// Maps FoodRx pantry category keys to Spoonacular `aisle` values.
/// Returns null when there is no reliable aisle — callers must treat search
/// as global and label the UI accordingly (invalid keys are ignored by the API).
String? spoonacularAisleForFoodRxCategory(String categoryKey) {
  switch (categoryKey) {
    case 'dairy':
      return 'Milk, Eggs, Other Dairy';
    case 'fresh_fruits':
    case 'fresh_veggies':
      return 'Produce';
    case 'canned_fruits':
    case 'canned_veggies':
      return 'Canned and Jarred';
    case 'grains':
      return 'Pasta and Rice';
    case 'meat':
    case 'protein': // legacy FoodRx key
      return 'Meat';
    case 'beans':
      return 'Canned and Jarred';
    case 'nuts_seeds':
      return 'Nuts';
    case 'seasonings':
      return 'Spices and Seasonings';
    case 'frozen_fruits':
    case 'frozen_veggies':
      return 'Frozen';
    case 'snacks_beverages':
    default:
      return null;
  }
}

// Helper function to get all category keys for food pantry items
List<String> get foodPantryCategoryKeys =>
    foodPantryCategories.map((cat) => cat['key']!).toList();

// Helper function to get all category keys for other pantry items
List<String> get otherPantryCategoryKeys =>
    otherPantryItemCategories.map((cat) => cat['key']!).toList();
