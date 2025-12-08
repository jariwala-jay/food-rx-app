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

// Tour step descriptions - kept SHORT for accessibility/large fonts
class TourDescriptions {
  // Common instruction suffix - short and clear
  static const String _tap = "\n\nTap highlighted area to continue";
  static const String _swipe = "\n\nSwipe left to continue";

  static const String trackers = "Track your daily nutrition goals here.$_tap";

  static const String trackerInfo = "Tap to see what counts as 1 serving.$_tap";

  static const String dailyTips =
      "Get daily health tips based on your conditions.$_tap";

  static const String myPlan =
      "View your complete personalized meal plan.$_tap";

  static const String addButton = "Add food items to your pantry.$_tap";

  static const String selectCategory =
      "Let's add an item. Tap 'Fresh Fruits' to continue.$_tap";

  static const String selectItem =
      "Tap the + button to add the first item.$_tap";

  static const String setQuantityUnit =
      "Set quantity and unit, then tap 'Add'.$_tap";

  static const String saveItem =
      "Tap 'Save' to add this item to your pantry.$_tap";

  static const String pantryItems =
      "Your pantry items help us suggest recipes.$_tap";

  static const String removePantryItem = "Swipe left to remove an item.$_swipe";

  static const String pantryList = "These items help us suggest recipes.$_tap";

  static const String recipes = "Personalized recipes based on your plan.$_tap";

  static const String education =
      "Expert articles for your health condition.$_tap";

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

/// Shared tooltip style configuration for tour showcases
/// Uses fixed font sizes to prevent overflow with accessibility settings
class TourTooltipStyle {
  // Fixed title style - won't scale with system font size
  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black,
    fontFamily: 'BricolageGrotesque',
  );

  // Fixed description style - won't scale with system font size
  static const TextStyle descriptionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
    height: 1.4,
    fontFamily: 'BricolageGrotesque',
  );

  // Common tooltip properties
  static const Color tooltipBackgroundColor = Colors.white;
  static const Color textColor = Colors.black;
  static const Color overlayColor = Colors.black54;
  static const double overlayOpacity = 0.8;
  static const double toolTipMargin = 16.0;
  static const EdgeInsets tooltipPadding = EdgeInsets.all(16);
}
