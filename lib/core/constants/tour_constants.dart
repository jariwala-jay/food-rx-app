import 'package:flutter/material.dart';

// GlobalKeys for showcase widgets
class TourKeys {
  static final GlobalKey trackersKey = GlobalKey(debugLabel: 'trackers');
  static final GlobalKey trackerInfoKey = GlobalKey(debugLabel: 'tracker_info');
  static final GlobalKey trackerSectionKey =
      GlobalKey(debugLabel: 'tracker_section');
  static final GlobalKey dailyTipsKey = GlobalKey(debugLabel: 'daily_tips');
  static final GlobalKey myPlanButtonKey =
      GlobalKey(debugLabel: 'my_plan_button');
  static final GlobalKey addButtonKey = GlobalKey(debugLabel: 'add_button');
  static final GlobalKey pantryTabKey = GlobalKey(debugLabel: 'pantry_tab');
  static final GlobalKey recipesTabKey = GlobalKey(debugLabel: 'recipes_tab');
  static final GlobalKey educationTabKey =
      GlobalKey(debugLabel: 'education_tab');
  static final GlobalKey pantryItemsKey = GlobalKey(debugLabel: 'pantry_items');
  static final GlobalKey pantryTabToggleKey =
      GlobalKey(debugLabel: 'pantry_tab_toggle');
  static final GlobalKey addFoodRxItemsKey =
      GlobalKey(debugLabel: 'add_foodrx_items');
  static final GlobalKey pantryCategoryListKey =
      GlobalKey(debugLabel: 'pantry_category_list');
  static final GlobalKey recipesKey = GlobalKey(debugLabel: 'recipes');
  static final GlobalKey recipeListKey = GlobalKey(debugLabel: 'recipe_list');
  static final GlobalKey generateRecipeButtonKey =
      GlobalKey(debugLabel: 'generate_recipe_button');
  static final GlobalKey educationKey = GlobalKey(debugLabel: 'education');
  static final GlobalKey educationContentKey =
      GlobalKey(debugLabel: 'education_content');
  static final GlobalKey recommendedArticlesKey =
      GlobalKey(debugLabel: 'recommended_articles');
  static final GlobalKey articlesListKey =
      GlobalKey(debugLabel: 'articles_list');
  static final GlobalKey selectItemKey = GlobalKey(debugLabel: 'select_item');
  static final GlobalKey quantityUnitKey =
      GlobalKey(debugLabel: 'quantity_unit');
  static final GlobalKey removePantryItemKey =
      GlobalKey(debugLabel: 'remove_pantry_item');
  static final GlobalKey saveItemButtonKey =
      GlobalKey(debugLabel: 'save_item_button');
}

// Tour step enum
enum TourStep {
  trackers,
  trackerInfo,
  dailyTips,
  myPlan,
  addButton,
  selectCategory,
  selectItem,
  setQuantityUnit,
  saveItem,
  pantryItems,
  removePantryItem,
  recipes,
  education,
}

// Tour step descriptions
class TourDescriptions {
  static const String trackers =
      "This is where you track your daily nutrition goals. You'll see how well you're following your personalized meal plan. Click on this section to continue.";

  static const String trackerInfo =
      "Tap the i icon to learn what counts as 1 serving for this tracker. You MUST click the i icon to continue.";

  static const String dailyTips =
      "Get helpful daily tips based on your health conditions to improve your well-being. Click on this section to continue.";

  static const String myPlan =
      "Tap here anytime to view your complete meal plan and learn about healthy eating for your condition. You MUST click this button to continue.";

  static const String addButton =
      "Tap the + button to add food items from your pantry or create healthy recipes. You MUST click this button to continue.";

  static const String selectCategory =
      "Here you can add items to your pantry. For this example, let's add an item together. Tap on 'Fresh Fruits' category to continue. You MUST click this category to proceed.";

  static const String selectItem =
      "Here you can add your items. For this example, let's add the first item shown. Tap the + button next to it to add it to your pantry. You MUST click the + button to continue.";

  static const String setQuantityUnit =
      "Set the quantity and unit for this item, then tap 'Add' to save it. You MUST click the Add button to continue.";

  static const String saveItem =
      "Now tap the 'Save' button to add this item to your pantry. You MUST click the Save button to continue.";

  static const String pantryItems =
      "Here are your pantry items! The more items you add, the better recipe recommendations you'll get. Click on this section to continue.";

  static const String removePantryItem =
      "To remove an item, swipe from right to left on any item. Try swiping left on the apple you just added to see how it works. You MUST swipe left to continue.";

  static const String pantryList =
      "Here are your pantry items! We'll use these to suggest recipes you can make. Click on this section to continue.";

  static const String recipes =
      "Browse these personalized recipes that match your meal plan and use your pantry items! Click on this section to continue.";

  static const String education =
      "Learn more about managing your health condition with expert articles and tips. Click on this section to continue.";

  // Skip tour option text
  static const String skipTour = "Skip tour";
}

// Tour theme configuration
class TourTheme {
  static const Color backgroundColor = Color(0xFFF7F7F8);
  static const Color accentColor = Color(0xFFFF6B35);
  static const Color overlayColor = Colors.black54;
  static const double borderRadius = 16.0;
  static const double tooltipPadding = 16.0;
  static const double tooltipFontSize = 16.0;
  static const String fontFamily = 'BricolageGrotesque';

  static ThemeData get theme => ThemeData(
        primaryColor: accentColor,
        fontFamily: fontFamily,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontSize: tooltipFontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      );
}
