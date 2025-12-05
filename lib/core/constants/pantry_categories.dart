// Constants for pantry categories
// Used in various pantry-related screens throughout the app

// Category data for "Food Pantry Items"
const List<Map<String, String>> foodPantryCategories = [
  {
    'icon': 'assets/icons/food_pantry_icons/fresh_fruits.svg',
    'title': 'Fresh Fruits',
    'subtitle': 'Select upto 4',
    'key': 'fresh_fruits',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/canned_fruits.svg',
    'title': 'Canned Fruits',
    'subtitle': 'Select upto 2',
    'key': 'canned_fruits',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/fresh_veggies.svg',
    'title': 'Fresh Veggies',
    'subtitle': 'Select upto 6',
    'key': 'fresh_veggies',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/canned_veggies.svg',
    'title': 'Canned Veggies',
    'subtitle': 'Select upto 4',
    'key': 'canned_veggies',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/grains.svg',
    'title': 'Grains And Cereals',
    'subtitle': 'Select upto 4',
    'key': 'grains',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/protein.svg',
    'title': 'Protein And Beans',
    'subtitle': 'Select upto 4',
    'key': 'protein',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/dairy.svg',
    'title': 'Dairy And Other',
    'subtitle': 'Select upto 4',
    'key': 'dairy',
  },
  {
    'icon': 'assets/icons/food_pantry_icons/seasonings.svg',
    'title': 'Seasonings & Spices',
    'subtitle': 'Select upto 2',
    'key': 'seasonings',
  },
];

// Category data for "Other Pantry Items"
const List<Map<String, String>> otherPantryItemCategories = [
  {
    'icon': 'assets/icons/other_pantry_icons/fresh_produce.svg',
    'title': 'Fresh Produce',
    'key': 'fresh_produce',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/dairyandeggs.svg',
    'title': 'Dairy And Eggs',
    'key': 'dairy_eggs',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/protein.svg',
    'title': 'Protein And Meat',
    'key': 'protein_meat',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/staples.svg',
    'title': 'Pantry Staples',
    'key': 'pantry_staples',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/frozen_food.svg',
    'title': 'Frozen Foods',
    'key': 'frozen_foods',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/snacks.svg',
    'title': 'Snacks And Beverages',
    'key': 'snacks_beverages',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/seasonings.svg',
    'title': 'Essentials And Condiments',
    'key': 'essentials_condiments',
  },
  {
    'icon': 'assets/icons/other_pantry_icons/miscellaneous.svg',
    'title': 'Miscellaneous',
    'key': 'miscellaneous',
  },
];

// Common pantry items for Food Pantry categories
// Based on typical American household pantry items and food bank distributions
const Map<String, List<Map<String, dynamic>>> commonFoodPantryItems = {
  'fresh_fruits': [
    {
      'name': 'Apples',
      'id': 'apple',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/apple.jpg'
    },
    {
      'name': 'Bananas',
      'id': 'banana',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bananas.jpg'
    },
    {
      'name': 'Oranges',
      'id': 'orange',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/orange.png'
    },
    {
      'name': 'Grapes',
      'id': 'grapes',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/red-grapes.jpg'
    },
    {
      'name': 'Strawberries',
      'id': 'strawberries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strawberries.jpg'
    },
    {
      'name': 'Lemons',
      'id': 'lemon',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/lemon.jpg'
    },
    {
      'name': 'Limes',
      'id': 'lime',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/lime.jpg'
    },
    {
      'name': 'Pears',
      'id': 'pear',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pears-bosc.jpg'
    },
    {
      'name': 'Peaches',
      'id': 'peach',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peach.png'
    },
    {
      'name': 'Plums',
      'id': 'plum',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/plum.jpg'
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
  ],
  'canned_fruits': [
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
      'name': 'Canned Pineapple',
      'id': 'canned-pineapple',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pineapple.jpg'
    },
    {
      'name': 'Applesauce',
      'id': 'applesauce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/applesauce.jpg'
    },
    {
      'name': 'Canned Mandarin Oranges',
      'id': 'canned-mandarin',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/orange.png'
    },
    {
      'name': 'Fruit Cocktail',
      'id': 'fruit-cocktail',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/fruit-cocktail.jpg'
    },
    {
      'name': 'Canned Cherries',
      'id': 'canned-cherries',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cherries.jpg'
    },
    {
      'name': 'Cranberry Sauce',
      'id': 'cranberry-sauce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cranberry-sauce.jpg'
    },
  ],
  'fresh_veggies': [
    {
      'name': 'Carrots',
      'id': 'carrots',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/carrots.jpg'
    },
    {
      'name': 'Onions',
      'id': 'onions',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brown-onion.png'
    },
    {
      'name': 'Potatoes',
      'id': 'potatoes',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/potatoes-yukon-gold.jpg'
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
      'name': 'Celery',
      'id': 'celery',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/celery.jpg'
    },
    {
      'name': 'Lettuce',
      'id': 'lettuce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/iceberg-lettuce.jpg'
    },
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
      'name': 'Cauliflower',
      'id': 'cauliflower',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cauliflower.jpg'
    },
    {
      'name': 'Cabbage',
      'id': 'cabbage',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cabbage.jpg'
    },
    {
      'name': 'Green Beans',
      'id': 'green-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/green-beans-or-string-beans.jpg'
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
      'name': 'Sweet Potatoes',
      'id': 'sweet-potatoes',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sweet-potato.jpg'
    },
  ],
  'canned_veggies': [
    {
      'name': 'Canned Corn',
      'id': 'canned-corn',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/corn.jpg'
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
      'name': 'Canned Carrots',
      'id': 'canned-carrots',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/carrots.jpg'
    },
    {
      'name': 'Canned Tomatoes',
      'id': 'canned-tomatoes',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/tomato.png'
    },
    {
      'name': 'Tomato Sauce',
      'id': 'tomato-sauce',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ketchup.png'
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
      'name': 'Canned Beets',
      'id': 'canned-beets',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/beets.jpg'
    },
    {
      'name': 'Canned Mixed Vegetables',
      'id': 'canned-mixed-vegetables',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mixed-vegetables.jpg'
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
      'name': 'Pasta',
      'id': 'pasta',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/fusilli.jpg'
    },
    {
      'name': 'Spaghetti',
      'id': 'spaghetti',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/spaghetti.jpg'
    },
    {
      'name': 'Bread',
      'id': 'bread',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-bread.jpg'
    },
    {
      'name': 'Oats',
      'id': 'oats',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/rolled-oats.jpg'
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
      'name': 'Cereal',
      'id': 'cereal',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cheerios.jpg'
    },
    {
      'name': 'Crackers',
      'id': 'crackers',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/crackers.jpg'
    },
    {
      'name': 'Flour',
      'id': 'flour',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/flour.jpg'
    },
    {
      'name': 'Cornmeal',
      'id': 'cornmeal',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cornmeal.jpg'
    },
  ],
  'protein': [
    {
      'name': 'Canned Tuna',
      'id': 'canned-tuna',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/canned-tuna.png'
    },
    {
      'name': 'Canned Salmon',
      'id': 'canned-salmon',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salmon.jpg'
    },
    {
      'name': 'Black Beans',
      'id': 'black-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/black-beans.jpg'
    },
    {
      'name': 'Kidney Beans',
      'id': 'kidney-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/kidney-beans.jpg'
    },
    {
      'name': 'Chickpeas',
      'id': 'chickpeas',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chickpeas.jpg'
    },
    {
      'name': 'Pinto Beans',
      'id': 'pinto-beans',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pinto-beans.jpg'
    },
    {
      'name': 'Lentils',
      'id': 'lentils',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/lentils-brown.jpg'
    },
    {
      'name': 'Peanut Butter',
      'id': 'peanut-butter',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/peanut-butter.jpg'
    },
    {
      'name': 'Canned Chicken',
      'id': 'canned-chicken',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/rotisserie-chicken.jpg'
    },
    {
      'name': 'Eggs',
      'id': 'eggs',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/egg.jpg'
    },
    {
      'name': 'Nuts',
      'id': 'nuts',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/nuts-mixed.jpg'
    },
    {
      'name': 'Split Peas',
      'id': 'split-peas',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/split-peas-green.jpg'
    },
  ],
  'dairy': [
    {
      'name': 'Milk',
      'id': 'milk',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/milk.jpg'
    },
    {
      'name': 'Cheese',
      'id': 'cheese',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cheddar-cheese.jpg'
    },
    {
      'name': 'Yogurt',
      'id': 'yogurt',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/plain-yogurt.jpg'
    },
    {
      'name': 'Butter',
      'id': 'butter',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/butter-sliced.jpg'
    },
    {
      'name': 'Cream Cheese',
      'id': 'cream-cheese',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cream-cheese.jpg'
    },
    {
      'name': 'Sour Cream',
      'id': 'sour-cream',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sour-cream.jpg'
    },
    {
      'name': 'Cottage Cheese',
      'id': 'cottage-cheese',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/cottage-cheese.jpg'
    },
    {
      'name': 'Powdered Milk',
      'id': 'powdered-milk',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/milk-powdered.jpg'
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
      'name': 'Cumin',
      'id': 'cumin',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ground-cumin.jpg'
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
      'name': 'Chili Powder',
      'id': 'chili-powder',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chili-powder.jpg'
    },
    {
      'name': 'Italian Seasoning',
      'id': 'italian-seasoning',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dried-herbs.png'
    },
  ],
};

// Common pantry items for Other Pantry categories
const Map<String, List<Map<String, dynamic>>> commonOtherPantryItems = {
  'fresh_produce': [
    {
      'name': 'Avocados',
      'id': 'avocado',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/avocado.jpg'
    },
    {
      'name': 'Mushrooms',
      'id': 'mushrooms',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mushrooms.jpg'
    },
    {
      'name': 'Garlic',
      'id': 'garlic',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/garlic.jpg'
    },
    {
      'name': 'Ginger',
      'id': 'ginger',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ginger.jpg'
    },
    {
      'name': 'Kale',
      'id': 'kale',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/kale.jpg'
    },
    {
      'name': 'Asparagus',
      'id': 'asparagus',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/asparagus.jpg'
    },
    {
      'name': 'Brussels Sprouts',
      'id': 'brussels-sprouts',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/brussels-sprouts.jpg'
    },
    {
      'name': 'Eggplant',
      'id': 'eggplant',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/eggplant.jpg'
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parsnips.jpg'
    },
    {
      'name': 'Leeks',
      'id': 'leeks',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/leeks.jpg'
    },
  ],
  'dairy_eggs': [
    {
      'name': 'Greek Yogurt',
      'id': 'greek-yogurt',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/greek-yogurt.jpg'
    },
    {
      'name': 'Mozzarella Cheese',
      'id': 'mozzarella',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mozzarella.jpg'
    },
    {
      'name': 'Parmesan Cheese',
      'id': 'parmesan',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/parmesan.jpg'
    },
    {
      'name': 'Swiss Cheese',
      'id': 'swiss-cheese',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/swiss-cheese.jpg'
    },
    {
      'name': 'Heavy Cream',
      'id': 'heavy-cream',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/heavy-cream.jpg'
    },
    {
      'name': 'Half and Half',
      'id': 'half-and-half',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/milk.jpg'
    },
    {
      'name': 'Buttermilk',
      'id': 'buttermilk',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/buttermilk.jpg'
    },
    {
      'name': 'Egg Whites',
      'id': 'egg-whites',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/egg-white.jpg'
    },
    {
      'name': 'Ricotta Cheese',
      'id': 'ricotta',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ricotta.jpg'
    },
    {
      'name': 'Feta Cheese',
      'id': 'feta',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/feta-cheese.jpg'
    },
  ],
  'protein_meat': [
    {
      'name': 'Chicken Breast',
      'id': 'chicken-breast',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chicken-breasts.jpg'
    },
    {
      'name': 'Ground Beef',
      'id': 'ground-beef',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ground-beef.jpg'
    },
    {
      'name': 'Ground Turkey',
      'id': 'ground-turkey',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/ground-turkey.jpg'
    },
    {
      'name': 'Salmon Fillet',
      'id': 'salmon-fillet',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salmon.jpg'
    },
    {
      'name': 'Pork Chops',
      'id': 'pork-chops',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pork-chops.jpg'
    },
    {
      'name': 'Beef Steak',
      'id': 'beef-steak',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/beef-sirloin.jpg'
    },
    {
      'name': 'Chicken Thighs',
      'id': 'chicken-thighs',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chicken-thighs.jpg'
    },
    {
      'name': 'Bacon',
      'id': 'bacon',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/bacon.jpg'
    },
    {
      'name': 'Ham',
      'id': 'ham',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/ham.jpg'
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
    {
      'name': 'Shrimp',
      'id': 'shrimp',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/shrimp.jpg'
    },
  ],
  'pantry_staples': [
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
      'name': 'Baking Powder',
      'id': 'baking-powder',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-powder.jpg'
    },
    {
      'name': 'Baking Soda',
      'id': 'baking-soda',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/baking-soda.jpg'
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
          'https://spoonacular.com/cdn/ingredients_100x100/brown-sugar.jpg'
    },
    {
      'name': 'Honey',
      'id': 'honey',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/honey.jpg'
    },
    {
      'name': 'Vanilla Extract',
      'id': 'vanilla-extract',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/vanilla-extract.jpg'
    },
    {
      'name': 'Vinegar',
      'id': 'vinegar',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/white-wine-vinegar.jpg'
    },
    {
      'name': 'Soy Sauce',
      'id': 'soy-sauce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/soy-sauce.jpg'
    },
    {
      'name': 'Hot Sauce',
      'id': 'hot-sauce',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/hot-sauce.jpg'
    },
    {
      'name': 'Worcestershire Sauce',
      'id': 'worcestershire',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/worcestershire-sauce.jpg'
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
  ],
  'frozen_foods': [
    {
      'name': 'Frozen Peas',
      'id': 'frozen-peas',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/peas.jpg'
    },
    {
      'name': 'Frozen Corn',
      'id': 'frozen-corn',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/corn.jpg'
    },
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
      'name': 'Frozen Berries',
      'id': 'frozen-berries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/mixed-berries.jpg'
    },
    {
      'name': 'Frozen Chicken Nuggets',
      'id': 'frozen-chicken-nuggets',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chicken-nuggets.jpg'
    },
    {
      'name': 'Frozen Fish Fillets',
      'id': 'frozen-fish',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/fish-fillet.jpg'
    },
    {
      'name': 'Frozen Pizza',
      'id': 'frozen-pizza',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/pizza.jpg'
    },
    {
      'name': 'Ice Cream',
      'id': 'ice-cream',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/vanilla-ice-cream.jpg'
    },
    {
      'name': 'Frozen Waffles',
      'id': 'frozen-waffles',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/waffles.jpg'
    },
  ],
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
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/chocolate-chip-cookies.jpg'
    },
    {
      'name': 'Granola Bars',
      'id': 'granola-bars',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/granola-bar.jpg'
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
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/cola.jpg'
    },
    {
      'name': 'Energy Drinks',
      'id': 'energy-drinks',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/energy-drink.jpg'
    },
    {
      'name': 'Sparkling Water',
      'id': 'sparkling-water',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/sparkling-water.jpg'
    },
    {
      'name': 'Trail Mix',
      'id': 'trail-mix',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/trail-mix.jpg'
    },
  ],
  'essentials_condiments': [
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
          'https://spoonacular.com/cdn/ingredients_100x100/tomato-sauce.jpg'
    },
    {
      'name': 'Salsa',
      'id': 'salsa',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/salsa.jpg'
    },
    {
      'name': 'Pickles',
      'id': 'pickles',
      'imageUrl': 'https://spoonacular.com/cdn/ingredients_100x100/pickles.jpg'
    },
    {
      'name': 'Relish',
      'id': 'relish',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/pickle-relish.jpg'
    },
    {
      'name': 'Jam/Jelly',
      'id': 'jam',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/strawberry-jam.jpg'
    },
    {
      'name': 'Peanut Butter',
      'id': 'peanut-butter-condiment',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/peanut-butter.jpg'
    },
    {
      'name': 'Maple Syrup',
      'id': 'maple-syrup',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/maple-syrup.jpg'
    },
  ],
  'miscellaneous': [
    {
      'name': 'Aluminum Foil',
      'id': 'aluminum-foil',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/aluminum-foil.jpg'
    },
    {
      'name': 'Plastic Wrap',
      'id': 'plastic-wrap',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/plastic-wrap.jpg'
    },
    {
      'name': 'Paper Towels',
      'id': 'paper-towels',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/paper-towels.jpg'
    },
    {
      'name': 'Trash Bags',
      'id': 'trash-bags',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/trash-bags.jpg'
    },
    {
      'name': 'Dish Soap',
      'id': 'dish-soap',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/dish-soap.jpg'
    },
    {
      'name': 'Laundry Detergent',
      'id': 'laundry-detergent',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/laundry-detergent.jpg'
    },
    {
      'name': 'Toilet Paper',
      'id': 'toilet-paper',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/toilet-paper.jpg'
    },
    {
      'name': 'Batteries',
      'id': 'batteries',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/batteries.jpg'
    },
    {
      'name': 'Light Bulbs',
      'id': 'light-bulbs',
      'imageUrl':
          'https://spoonacular.com/cdn/ingredients_100x100/light-bulbs.jpg'
    },
  ],
};

// Helper function to get common items for a category
List<Map<String, dynamic>> getCommonItemsForCategory(
    String categoryKey, bool isFoodPantryItem) {
  if (isFoodPantryItem) {
    return commonFoodPantryItems[categoryKey] ?? [];
  } else {
    return commonOtherPantryItems[categoryKey] ?? [];
  }
}

// Helper function to get all category keys for food pantry items
List<String> get foodPantryCategoryKeys =>
    foodPantryCategories.map((cat) => cat['key']!).toList();

// Helper function to get all category keys for other pantry items
List<String> get otherPantryCategoryKeys =>
    otherPantryItemCategories.map((cat) => cat['key']!).toList();
