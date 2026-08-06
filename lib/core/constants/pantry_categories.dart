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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/apple.jpg'
    },
    {
      'name': 'Strawberries',
      'id': 'strawberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strawberries.jpg'
    },
    {
      'name': 'Blueberries',
      'id': 'blueberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/blueberries.jpg'
    },
    {
      'name': 'Raspberries',
      'id': 'raspberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/raspberries.jpg'
    },
    {
      'name': 'Oranges',
      'id': 'oranges',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/orange.png'
    },
    {
      'name': 'Pears',
      'id': 'pears',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pears-bosc.jpg'
    },
    {
      'name': 'Grapefruit',
      'id': 'grapefruit',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/grapefruit.jpg'
    },
    {
      'name': 'Pomegranate',
      'id': 'pomegranate',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pomegranate.jpg'
    },
    {
      'name': 'Avocado',
      'id': 'avocado',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/avocado.jpg'
    },
    {
      'name': 'Kiwi',
      'id': 'kiwi',
      'imageAsset': 'assets/pantry_ingredients/kiwi.jpg',
    },
    {
      'name': 'Bananas',
      'id': 'bananas',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bananas.jpg'
    },
    {
      'name': 'Grapes',
      'id': 'grapes',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/red-grapes.jpg'
    },
    {
      'name': 'Peaches',
      'id': 'peaches',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peach.png'
    },
    {
      'name': 'Plums',
      'id': 'plums',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/plum.jpg'
    },
    {
      'name': 'Clementines',
      'id': 'clementines',
      'imageAsset': 'assets/pantry_ingredients/clementines.jpg',
    },
    {
      'name': 'Watermelon',
      'id': 'watermelon',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/watermelon.jpg'
    },
    {
      'name': 'Cantaloupe',
      'id': 'cantaloupe',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cantaloupe.jpg'
    },
    {
      'name': 'Mango',
      'id': 'mango',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/mango.jpg'
    },
    {
      'name': 'Pineapple',
      'id': 'pineapple',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pineapple.jpg'
    },
    {
      'name': 'Lemons',
      'id': 'lemons',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/lemon.jpg'
    },
    {
      'name': 'Limes',
      'id': 'limes',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/lime.jpg'
    },
    {
      'name': 'Dates',
      'id': 'dates',
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/orange.png'
    },
    {
      'name': 'Canned Pineapple',
      'id': 'canned-pineapple',
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
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/fruit-cocktail.jpg'
    },
  ],
  'fresh_veggies': [
    {
      'name': 'Spinach',
      'id': 'spinach',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/spinach.jpg'
    },
    {
      'name': 'Broccoli',
      'id': 'broccoli',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/broccoli.jpg'
    },
    {
      'name': 'Carrots',
      'id': 'carrots',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/carrots.jpg'
    },
    {
      'name': 'Tomatoes',
      'id': 'tomatoes',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tomato.png'
    },
    {
      'name': 'Bell Peppers',
      'id': 'bell-peppers',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/green-pepper.jpg'
    },
    {
      'name': 'Onions',
      'id': 'onions',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brown-onion.png'
    },
    {
      'name': 'Garlic',
      'id': 'garlic',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/garlic.jpg'
    },
    {
      'name': 'Cucumber',
      'id': 'cucumber',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cucumber.jpg'
    },
    {
      'name': 'Zucchini',
      'id': 'zucchini',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/zucchini.jpg'
    },
    {
      'name': 'Cauliflower',
      'id': 'cauliflower',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cauliflower.jpg'
    },
    {
      'name': 'Green Beans',
      'id': 'green-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/green-beans-or-string-beans.jpg'
    },
    {
      'name': 'Sweet Potatoes',
      'id': 'sweet-potatoes',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sweet-potato.jpg'
    },
    {
      'name': 'Kale',
      'id': 'kale',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/kale.jpg'
    },
    {
      'name': 'Romaine Lettuce',
      'id': 'romaine-lettuce',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/romaine.jpg'
    },
    {
      'name': 'Lettuce',
      'id': 'lettuce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/iceberg-lettuce.jpg'
    },
    {
      'name': 'Collard Greens',
      'id': 'collard-greens',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/collard-greens.jpg'
    },
    {
      'name': 'Swiss Chard',
      'id': 'swiss-chard',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/swiss-chard.jpg'
    },
    {
      'name': 'Brussels Sprouts',
      'id': 'brussels-sprouts',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brussels-sprouts.jpg'
    },
    {
      'name': 'Asparagus',
      'id': 'asparagus',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/asparagus.jpg'
    },
    {
      'name': 'Cabbage',
      'id': 'cabbage',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cabbage.jpg'
    },
    {
      'name': 'Mushrooms',
      'id': 'mushrooms',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mushrooms.jpg'
    },
    {
      'name': 'Celery',
      'id': 'celery',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/celery.jpg'
    },
    {
      'name': 'Eggplant',
      'id': 'eggplant',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/eggplant.jpg'
    },
    {
      'name': 'Butternut Squash',
      'id': 'butternut-squash',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/butternut-squash.jpg'
    },
    {
      'name': 'Potatoes',
      'id': 'potatoes',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/potatoes-yukon-gold.jpg'
    },
    {
      'name': 'Corn',
      'id': 'corn',
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/okra.png'
    },
    {
      'name': 'Beets',
      'id': 'beets',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/beets.jpg'
    },
    {
      'name': 'Radishes',
      'id': 'radishes',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/radishes.jpg'
    },
    {
      'name': 'Turnips',
      'id': 'turnips',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/turnips.jpg'
    },
    {
      'name': 'Parsnips',
      'id': 'parsnips',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parsnip.jpg'
    },
    {
      'name': 'Leeks',
      'id': 'leeks',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/leeks.jpg'
    },
    {
      'name': 'Ginger',
      'id': 'ginger',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ginger.jpg'
    },
    {
      'name': 'Chili Peppers',
      'id': 'chili-peppers',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/red-chili.jpg'
    },
    {
      'name': 'Jalapeno',
      'id': 'jalapeno',
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/corn.jpg'
    },
  ],
  'canned_veggies': [
    {
      'name': 'Canned Tomatoes',
      'id': 'canned-tomatoes',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tomato.png'
    },
    {
      'name': 'Tomato Sauce',
      'id': 'tomato-sauce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/tomato-sauce-or-pasta-sauce.jpg'
    },
    {
      'name': 'Tomato Paste',
      'id': 'tomato-paste',
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/beets.jpg'
    },
    {
      'name': 'Canned Mushrooms',
      'id': 'canned-mushrooms',
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
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-bread.jpg'
    },
    {
      'name': 'Whole Wheat Bread',
      'id': 'whole-wheat-bread',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/whole-wheat-bread.jpg'
    },
    {
      'name': 'Pasta',
      'id': 'pasta',
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
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/spaghetti.jpg'
    },
    {
      'name': 'Tortillas',
      'id': 'tortillas',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/flour-tortilla.jpg'
    },
    {
      'name': 'Whole Wheat Flour',
      'id': 'whole-wheat-flour',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/flour.png'
    },
    {
      'name': 'Oats',
      'id': 'oats',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/rolled-oats.jpg'
    },
    {
      'name': 'Steel Cut Oats',
      'id': 'steel-cut-oats',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/steel-cut-oats.png'
    },
    {
      'name': 'Quinoa',
      'id': 'quinoa',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/quinoa.jpg'
    },
    {
      'name': 'Barley',
      'id': 'barley',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pearl-barley.png'
    },
    {
      'name': 'Farro',
      'id': 'farro',
      'imageAsset': 'assets/pantry_ingredients/farro.jpg',
    },
    {
      'name': 'Bulgur',
      'id': 'bulgur',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bulgur.jpg'
    },
    {
      'name': 'Couscous',
      'id': 'couscous',
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cornmeal.jpg'
    },
  ],
  'meat': [
    {
      'name': 'Chicken Breast',
      'id': 'chicken-breast',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chicken-breasts.jpg'
    },
    {
      'name': 'Chicken Thighs',
      'id': 'chicken-thighs',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chicken-thighs.jpg'
    },
    {
      'name': 'Ground Chicken',
      'id': 'ground-chicken',
      'imageAsset': 'assets/pantry_ingredients/ground_chicken.jpg',
    },
    {
      'name': 'Canned Chicken',
      'id': 'canned-chicken',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/rotisserie-chicken.jpg'
    },
    {
      'name': 'Turkey Breast',
      'id': 'turkey-breast',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/turkey-breast.jpg'
    },
    {
      'name': 'Ground Turkey',
      'id': 'ground-turkey',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/meat-ground.jpg'
    },
    {
      'name': 'Salmon Fillet',
      'id': 'salmon-fillet',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salmon.jpg'
    },
    {
      'name': 'Canned Salmon',
      'id': 'canned-salmon',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salmon.jpg'
    },
    {
      'name': 'Tilapia',
      'id': 'tilapia',
      'imageAsset': 'assets/pantry_ingredients/tilapia.jpg',
    },
    {
      'name': 'Cod',
      'id': 'cod',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cod-fillet.jpg'
    },
    {
      'name': 'Shrimp',
      'id': 'shrimp',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/shrimp.jpg'
    },
    {
      'name': 'Canned Tuna',
      'id': 'canned-tuna',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/canned-tuna.png'
    },
    {
      'name': 'Ground Beef',
      'id': 'ground-beef',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/beef-brisket.jpg'
    },
    {
      'name': 'Beef Steak',
      'id': 'beef-steak',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strip-steak.jpg'
    },
    {
      'name': 'Pork Chops',
      'id': 'pork-chops',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pork-chops.jpg'
    },
    {
      'name': 'Ham',
      'id': 'ham',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ham.jpg'
    },
    {
      'name': 'Bacon',
      'id': 'bacon',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bacon.jpg'
    },
    {
      'name': 'Tofu',
      'id': 'tofu',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tofu.jpg'
    },
    {
      'name': 'Tempeh',
      'id': 'tempeh',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tempeh.jpg'
    },
  ],
  'beans': [
    {
      'name': 'Black Beans',
      'id': 'black-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/black-beans.jpg'
    },
    {
      'name': 'Chickpeas',
      'id': 'chickpeas',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chickpeas.jpg'
    },
    {
      'name': 'Kidney Beans',
      'id': 'kidney-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/kidney-beans.jpg'
    },
    {
      'name': 'Pinto Beans',
      'id': 'pinto-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pinto-beans.jpg'
    },
    {
      'name': 'White Beans',
      'id': 'white-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-beans.jpg'
    },
    {
      'name': 'Cannellini Beans',
      'id': 'cannellini-beans',
      'imageAsset': 'assets/pantry_ingredients/cannellini_beans.jpg',
    },
    {
      'name': 'Navy Beans',
      'id': 'navy-beans',
      'imageAsset': 'assets/pantry_ingredients/navy_beans.jpg',
    },
    {
      'name': 'Lentils',
      'id': 'lentils',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/lentils-brown.jpg'
    },
    {
      'name': 'Split Peas',
      'id': 'split-peas',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/split-peas-green.jpg'
    },
    {
      'name': 'Black Eyed Peas',
      'id': 'black-eyed-peas',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/black-eyed-peas.jpg'
    },
  ],
  'dairy': [
    {
      'name': 'Milk',
      'id': 'milk',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/milk.jpg'
    },
    {
      'name': 'Low Fat Milk',
      'id': 'low-fat-milk',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/milk.jpg'
    },
    {
      'name': 'Almond Milk',
      'id': 'almond-milk',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/almond-milk.jpg'
    },
    {
      'name': 'Half and Half',
      'id': 'half-and-half',
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
      'imageAsset': 'assets/pantry_ingredients/buttermilk.png',
    },
    {
      'name': 'Powdered Milk',
      'id': 'powdered-milk',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/milk-powdered.jpg'
    },
    {
      'name': 'Evaporated Milk',
      'id': 'evaporated-milk',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/evaporated-milk.png'
    },
    {
      'name': 'Yogurt',
      'id': 'yogurt',
      'imageAsset': 'assets/pantry_ingredients/yogurt.jpg',
    },
    {
      'name': 'Greek Yogurt',
      'id': 'greek-yogurt',
      'imageAsset': 'assets/pantry_ingredients/greek_yogurt.jpg',
    },
    {
      'name': 'Cheese',
      'id': 'cheese',
      'imageAsset': 'assets/pantry_ingredients/cheese.jpg',
    },
    {
      'name': 'Cottage Cheese',
      'id': 'cottage-cheese',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cottage-cheese.jpg'
    },
    {
      'name': 'Cream Cheese',
      'id': 'cream-cheese',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cream-cheese.jpg'
    },
    {
      'name': 'Mozzarella Cheese',
      'id': 'mozzarella',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mozzarella-balls.jpg'
    },
    {
      'name': 'Parmesan Cheese',
      'id': 'parmesan',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parmesan.jpg'
    },
    {
      'name': 'Swiss Cheese',
      'id': 'swiss-cheese',
      'imageAsset': 'assets/pantry_ingredients/swiss_cheese.jpg'
    },
    {
      'name': 'Ricotta Cheese',
      'id': 'ricotta',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ricotta-cheese.jpg'
    },
    {
      'name': 'Feta Cheese',
      'id': 'feta',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/feta-cheese.jpg'
    },
    {
      'name': 'Butter',
      'id': 'butter',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/butter-sliced.jpg'
    },
    {
      'name': 'Sour Cream',
      'id': 'sour-cream',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sour-cream.jpg'
    },
    {
      'name': 'Eggs',
      'id': 'eggs',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/egg.jpg'
    },
    {
      'name': 'Egg Whites',
      'id': 'egg-whites',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/egg-white.jpg'
    },
  ],
  'nuts_seeds': [
    {
      'name': 'Almonds',
      'id': 'almonds',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/almonds.jpg'
    },
    {
      'name': 'Walnuts',
      'id': 'walnuts',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/walnuts.jpg'
    },
    {
      'name': 'Peanuts',
      'id': 'peanuts',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peanuts.png'
    },
    {
      'name': 'Cashews',
      'id': 'cashews',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cashews.jpg'
    },
    {
      'name': 'Pistachios',
      'id': 'pistachios',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pistachios.jpg'
    },
    {
      'name': 'Pecans',
      'id': 'pecans',
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
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chia-seeds.jpg'
    },
    {
      'name': 'Flax Seeds',
      'id': 'flax-seeds',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/flax-seeds.png'
    },
    {
      'name': 'Sunflower Seeds',
      'id': 'sunflower-seeds',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sunflower-seeds.jpg'
    },
    {
      'name': 'Pumpkin Seeds',
      'id': 'pumpkin-seeds',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pumpkin-seeds.jpg'
    },
    {
      'name': 'Sesame Seeds',
      'id': 'sesame-seeds',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sesame-seeds.jpg'
    },
    {
      'name': 'Hemp Seeds',
      'id': 'hemp-seeds',
      'imageAsset': 'assets/pantry_ingredients/hemp_hearts.jpg',
    },
  ],
  'seasonings': [
    {
      'name': 'Salt',
      'id': 'salt',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salt.jpg'
    },
    {
      'name': 'Black Pepper',
      'id': 'black-pepper',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/pepper.jpg'
    },
    {
      'name': 'Garlic Powder',
      'id': 'garlic-powder',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/garlic-powder.jpg'
    },
    {
      'name': 'Onion Powder',
      'id': 'onion-powder',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/onion-powder.jpg'
    },
    {
      'name': 'Paprika',
      'id': 'paprika',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/paprika.jpg'
    },
    {
      'name': 'Chili Powder',
      'id': 'chili-powder',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chili-powder.jpg'
    },
    {
      'name': 'Red Pepper Flakes',
      'id': 'red-pepper-flakes',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/red-pepper-flakes.jpg'
    },
    {
      'name': 'Ground Cayenne Pepper',
      'id': 'ground-cayenne-pepper',
      'imageAsset': 'assets/pantry_ingredients/ground_cayenne_pepper.jpg',
    },
    {
      'name': 'Turmeric',
      'id': 'turmeric',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/turmeric.jpg'
    },
    {
      'name': 'Ginger Powder',
      'id': 'ginger-powder',
      'imageAsset': 'assets/pantry_ingredients/ginger_powder.jpg',
    },
    {
      'name': 'Cumin',
      'id': 'cumin',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ground-cumin.jpg'
    },
    {
      'name': 'Curry Powder',
      'id': 'curry-powder',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/curry-powder.jpg'
    },
    {
      'name': 'Oregano',
      'id': 'oregano',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/oregano.jpg'
    },
    {
      'name': 'Basil',
      'id': 'basil',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/basil.jpg'
    },
    {
      'name': 'Thyme',
      'id': 'thyme',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/thyme.jpg'
    },
    {
      'name': 'Bay Leaves',
      'id': 'bay-leaves',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/bay-leaves.jpg'
    },
    {
      'name': 'Italian Seasoning',
      'id': 'italian-seasoning',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dried-herbs.png'
    },
    {
      'name': 'Cinnamon',
      'id': 'cinnamon',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cinnamon.jpg'
    },
    {
      'name': 'Nutmeg',
      'id': 'nutmeg',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/nutmeg.jpg'
    },
    {
      'name': 'Parsley',
      'id': 'parsley',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parsley.jpg'
    },
    {
      'name': 'Cilantro',
      'id': 'cilantro',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cilantro.jpg'
    },
    {
      'name': 'Olive Oil',
      'id': 'olive-oil',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/olive-oil.jpg'
    },
    {
      'name': 'Vegetable Oil',
      'id': 'vegetable-oil',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/vegetable-oil.jpg'
    },
    {
      'name': 'Coconut Oil',
      'id': 'coconut-oil',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/coconut-oil.jpg'
    },
    {
      'name': 'Sesame Oil',
      'id': 'sesame-oil',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sesame-oil.jpg'
    },
    {
      'name': 'Vinegar',
      'id': 'vinegar',
      'imageAsset': 'assets/pantry_ingredients/vinegar.png',
    },
    {
      'name': 'Apple Cider Vinegar',
      'id': 'apple-cider-vinegar',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/apple-cider-vinegar.jpg'
    },
    {
      'name': 'Balsamic Vinegar',
      'id': 'balsamic-vinegar',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/balsamic-vinegar.jpg'
    },
    {
      'name': 'Distilled White Vinegar',
      'id': 'distilled-white-vinegar',
      'imageAsset': 'assets/pantry_ingredients/distilled_white_vinegar.png',
    },
    {
      'name': 'Baking Powder',
      'id': 'baking-powder',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-powder.jpg'
    },
    {
      'name': 'Baking Soda',
      'id': 'baking-soda',
      'imageAsset': 'assets/pantry_ingredients/baking_soda.png',
    },
    {
      'name': 'Vanilla Extract',
      'id': 'vanilla-extract',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/vanilla-extract.jpg'
    },
    {
      'name': 'Sugar',
      'id': 'sugar',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sugar-in-bowl.jpg'
    },
    {
      'name': 'Brown Sugar',
      'id': 'brown-sugar',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/light-brown-sugar.jpg'
    },
    {
      'name': 'Honey',
      'id': 'honey',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/honey.jpg'
    },
    {
      'name': 'Maple Syrup',
      'id': 'maple-syrup',
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
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/soy-sauce.jpg'
    },
    {
      'name': 'Worcestershire Sauce',
      'id': 'worcestershire',
      'imageAsset': 'assets/pantry_ingredients/worcestershire_sauce.png',
    },
    {
      'name': 'Hot Sauce',
      'id': 'hot-sauce',
      'imageAsset': 'assets/pantry_ingredients/hot_sauce.png',
    },
    {
      'name': 'Ketchup',
      'id': 'ketchup',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ketchup.jpg'
    },
    {
      'name': 'Mustard',
      'id': 'mustard',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dijon-mustard.jpg'
    },
    {
      'name': 'Mayonnaise',
      'id': 'mayonnaise',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mayonnaise.jpg'
    },
    {
      'name': 'Salad Dressing',
      'id': 'salad-dressing',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ranch-dressing.jpg'
    },
    {
      'name': 'BBQ Sauce',
      'id': 'bbq-sauce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/barbecue-sauce.jpg'
    },
    {
      'name': 'Pasta Sauce',
      'id': 'pasta-sauce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/tomato-paste.jpg'
    },
    {
      'name': 'Salsa',
      'id': 'salsa',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salsa.jpg'
    },
    {
      'name': 'Pickles',
      'id': 'pickles',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dill-pickles.jpg'
    },
    {
      'name': 'Relish',
      'id': 'relish',
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/popcorn.jpg'
    },
    {
      'name': 'Coffee',
      'id': 'coffee',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brewed-coffee.jpg'
    },
    {
      'name': 'Tea',
      'id': 'tea',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tea-bags.jpg'
    },
    {
      'name': 'Juice',
      'id': 'juice',
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
