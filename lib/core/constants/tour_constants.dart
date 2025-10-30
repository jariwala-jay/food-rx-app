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
}

// Tour step enum
enum TourStep {
  trackers,
  trackerInfo,
  dailyTips,
  myPlan,
  addButton,
  pantryItems,
  recipes,
  education,
}

// Tour step descriptions
class TourDescriptions {
  static const String trackers =
      "This is where you track your daily nutrition goals. You'll see how well you're following your personalized meal plan. Click on this section to continue.";

  static const String trackerInfo =
      "Tap the i icon to learn what counts as 1 serving for this tracker.";

  static const String dailyTips =
      "Get helpful daily tips based on your health conditions to improve your well-being. Click on this section to continue.";

  static const String myPlan =
      "Tap here anytime to view your complete diet plan and learn about healthy eating for your condition. You MUST click this button to continue.";

  static const String addButton =
      "Tap the + button to add food items from your pantry or create healthy recipes. You MUST click this button to continue.";

  static const String pantryItems =
      "Let's add items you got from food pharmacy. This helps us suggest recipes you can actually make! Click on this section to continue.";

  static const String pantryList =
      "Here are your pantry items! We'll use these to suggest recipes you can make. Click on this section to continue.";

  static const String recipes =
      "Browse these personalized recipes that match your diet plan and use your pantry items! Click on this section to continue.";

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
