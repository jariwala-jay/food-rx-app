import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart'
    as domain_repo;
import 'package:flutter_app/features/recipes/services/cooking_service.dart';
import 'package:flutter_app/features/recipes/services/meal_logging_service.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';

class RecipeController extends ChangeNotifier {
  final RecipeGenerationService recipeGenerationService;
  final domain_repo.RecipeRepository recipeRepository;
  final CookingService cookingService;
  final MealLoggingService? mealLoggingService;
  final TrackerProvider? trackerProvider;
  AuthController authProvider;
  PantryController pantryController;

  RecipeController({
    required this.recipeGenerationService,
    required this.recipeRepository,
    required this.authProvider,
    required this.pantryController,
    required this.cookingService,
    this.mealLoggingService,
    this.trackerProvider,
  });

  // State
  List<Recipe> _recipes = [];
  List<Recipe> _savedRecipes = [];
  RecipeFilter _currentFilter = const RecipeFilter();
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Recipe> get recipes => _recipes;
  List<Recipe> get savedRecipes => _savedRecipes;
  RecipeFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserModel? get currentUser => authProvider.currentUser;
  List<PantryItem> get pantryItems => pantryController.pantryItems;

  List<String> get userMedicalConditionsDisplay {
    final conditions = currentUser?.medicalConditions ?? [];
    return conditions.map((conditionStr) {
      try {
        final conditionEnum = MedicalCondition.values.firstWhere(
          (e) => e.name.toLowerCase() == conditionStr.toLowerCase(),
        );
        return conditionEnum.displayName;
      } catch (e) {
        return conditionStr.isNotEmpty
            ? conditionStr[0].toUpperCase() + conditionStr.substring(1)
            : '';
      }
    }).toList();
  }

  void initialize() {
    // Listeners can be set up here if needed
    // e.g., _authProvider.addListener(_onAuthChanged);
    loadSavedRecipes();
  }

  Future<void> generateRecipes({RecipeFilter? filter}) async {
    _isLoading = true;
    _error = null;
    if (filter != null) {
      _currentFilter = filter;
    }
    notifyListeners();

    try {
      final user = authProvider.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      await pantryController.loadItems();
      final pantryItems = pantryController.pantryItems;
      final userProfile = {
        'dietPlan': user.dietType,
        'medicalConditions': user.medicalConditions,
      };

      _recipes = await recipeGenerationService.generateRecipes(
        filter: _currentFilter,
        pantryItems: pantryItems,
        userProfile: userProfile,
      );
    } catch (e) {
      _error = "Failed to generate recipes: $e";
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateFilter(RecipeFilter newFilter) {
    _currentFilter = newFilter;
    notifyListeners();
    generateRecipes();
  }

  Future<void> refreshPantryItems() async {
    await pantryController.loadItems();
    notifyListeners();
  }

  Future<void> loadSavedRecipes() async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    _savedRecipes = await recipeRepository.getSavedRecipes(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveRecipe(Recipe recipe) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    await recipeRepository.saveRecipe(userId, recipe);
    _savedRecipes.add(recipe.copyWith(isSaved: true));
    notifyListeners();
  }

  Future<void> unsaveRecipe(int recipeId) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    await recipeRepository.unsaveRecipe(userId, recipeId);
    _savedRecipes.removeWhere((r) => r.id == recipeId);
    notifyListeners();
  }

  bool isRecipeSaved(int recipeId) {
    return _savedRecipes.any((r) => r.id == recipeId);
  }

  /// Cook a recipe with enhanced diet tracking
  Future<void> cookRecipe(Recipe recipe,
      {int? servingsConsumed, int? totalServingsToDeduct}) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final actualServingsConsumed = servingsConsumed ?? 1;
      final actualServingsToDeduct =
          totalServingsToDeduct ?? actualServingsConsumed;
      final dietType = currentUser!.dietType ?? 'MyPlate';

      await cookingService.cookRecipe(
        userId: userId,
        recipe: recipe,
        servingsConsumed: actualServingsConsumed,
        servingsToDeduct: actualServingsToDeduct,
        dietType: dietType,
      );

      // Force refresh pantry to update UI
      await pantryController.loadItems();

      // Force refresh tracker UI if available
      if (trackerProvider != null) {
        trackerProvider!.forceUIRefresh();
      }
    } catch (e) {
      _error = "Failed to cook recipe: $e";
      if (kDebugMode) {
        print('❌ Error cooking recipe: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a preview of what diet trackers would be updated
  Future<List<TrackerPreview>> getTrackingPreview(
      Recipe recipe, int servings) async {
    if (mealLoggingService == null || currentUser == null) {
      return [];
    }

    final userId = currentUser!.id;
    final dietType = currentUser!.dietType ?? 'MyPlate';

    if (userId == null) return [];

    try {
      return await mealLoggingService!.getTrackingPreview(
        recipe: recipe,
        servingsConsumed: servings,
        userId: userId,
        dietType: dietType,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting tracking preview: $e');
      }
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
