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

class RecipeController extends ChangeNotifier {
  final RecipeGenerationService recipeGenerationService;
  final domain_repo.RecipeRepository recipeRepository;
  AuthController authProvider;
  PantryController pantryController;

  RecipeController({
    required this.recipeGenerationService,
    required this.recipeRepository,
    required this.authProvider,
    required this.pantryController,
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
      
      // Create comprehensive user profile for recipe filtering
      final userProfile = {
        'dietType': user.dietType,
        'medicalConditions': user.medicalConditions ?? [],
        'healthGoals': user.healthGoals,
        'allergies': user.allergies ?? [],
        'foodRestrictions': user.foodRestrictions ?? [],
        'excludedIngredients': user.excludedIngredients ?? [],
        'activityLevel': user.activityLevel,
        'age': user.age,
        'gender': user.gender,
        'targetCalories': user.targetCalories,
      };

      if (kDebugMode) {
        print('🎯 Recipe generation with profile:');
        print('   Diet Type: ${userProfile['dietType']}');
        print('   Medical Conditions: ${userProfile['medicalConditions']}');
        print('   Health Goals: ${userProfile['healthGoals']}');
        print('   Allergies: ${userProfile['allergies']}');
      }

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

  Future<void> cookRecipe(Recipe recipe) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Deduct ingredients from pantry
      await pantryController.deductIngredientsForRecipe(recipe);

      // 2. Log the meal in the user's history (via RecipeRepository)
      await recipeRepository.cookRecipe(userId, recipe);

      // 3. Update trackers (This might move to a dedicated TrackerService later)
      //_trackerProvider.logMeal(recipe);
    } catch (e) {
      _error = "Failed to cook recipe: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
