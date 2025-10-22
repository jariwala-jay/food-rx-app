import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/auth/views/login_page.dart';
import 'package:flutter_app/features/auth/views/signup_page.dart';
import 'package:flutter_app/features/chatbot/views/chatbot_page.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/repositories/article_repository.dart';
import 'package:flutter_app/features/education/repositories/mongo_article_repository.dart';
import 'package:flutter_app/features/education/views/article_detail_page.dart';
import 'package:flutter_app/features/home/views/meal_plan_page.dart';
import 'package:flutter_app/features/home/views/diet_plan_viewer_page.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/pantry/repositories/ingredient_repository.dart';
import 'package:flutter_app/features/pantry/repositories/spoonacular_ingredient_repository.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/mongo_recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository_impl.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/features/home/providers/tip_provider.dart';
import 'package:flutter_app/features/chatbot/services/dialogflow_service.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/features/home/services/tip_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/features/navigation/views/main_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    DialogflowService.initialize();

    final mongoDBService = MongoDBService();
    await mongoDBService.initialize();

    runApp(
      MultiProvider(
        providers: [
          // Core services
          Provider<MongoDBService>.value(value: mongoDBService),
          Provider<UnitConversionService>(
              create: (_) => UnitConversionService()),
          Provider<FoodCategoryService>(
              create: (context) => FoodCategoryService(
                  conversionService: context.read<UnitConversionService>())),
          Provider<IngredientSubstitutionService>(
              create: (context) => IngredientSubstitutionService(
                  conversionService: context.read<UnitConversionService>())),
          Provider<PantryDeductionService>(
              create: (context) => PantryDeductionService(
                  conversionService: context.read<UnitConversionService>(),
                  substitutionService:
                      context.read<IngredientSubstitutionService>())),
          Provider<DietServingService>(
              create: (context) => DietServingService(
                  conversionService: context.read<UnitConversionService>())),
          Provider<DietConstraintsService>(
              create: (context) => DietConstraintsService()),

          // Feature-specific Repositories
          Provider<ArticleRepository>(
            create: (context) =>
                MongoArticleRepository(context.read<MongoDBService>()),
          ),
          Provider<RecipeRepository>(
            create: (context) => RecipeRepositoryImpl(
              SpoonacularRecipeRepository(),
              MongoRecipeRepository(context.read<MongoDBService>()),
            ),
          ),
          Provider<IngredientRepository>(
            create: (context) => SpoonacularIngredientRepository(),
          ),

          // Core Controllers / State Managers
          ChangeNotifierProvider(create: (_) => AuthController()..initialize()),
          ChangeNotifierProvider(create: (_) => SignupProvider()),
          ChangeNotifierProvider(create: (_) => TrackerProvider()),

          // Dependent Controllers (as ProxyProviders)
          ChangeNotifierProvider(
              create: (context) =>
                  TipProvider(TipService(context.read<MongoDBService>()))),

          ChangeNotifierProxyProvider<AuthController, PantryController>(
            create: (context) => PantryController(
              context.read<MongoDBService>(),
              conversionService: context.read<UnitConversionService>(),
              ingredientSubstitutionService:
                  context.read<IngredientSubstitutionService>(),
            ),
            update: (context, auth, pantry) {
              if (auth.isAuthenticated) {
                pantry!.initializeWithUser(auth.currentUser!.id!);
              }
              return pantry!;
            },
          ),

          ChangeNotifierProxyProvider<AuthController, ArticleController>(
              create: (context) => ArticleController(
                    context.read<ArticleRepository>(),
                    context.read<AuthController>(),
                  ),
              update: (context, auth, articleController) {
                articleController!.authProvider = auth;
                return articleController;
              }),

          ChangeNotifierProxyProvider3<AuthController, PantryController,
              TrackerProvider, RecipeController>(
            create: (context) => RecipeController(
              recipeGenerationService: RecipeGenerationService(
                recipeRepository: context.read<RecipeRepository>(),
                unitConversionService: context.read<UnitConversionService>(),
                foodCategoryService: context.read<FoodCategoryService>(),
                ingredientSubstitutionService:
                    context.read<IngredientSubstitutionService>(),
                dietConstraintsService: context.read<DietConstraintsService>(),
              ),
              recipeRepository: context.read<RecipeRepository>(),
              pantryDeductionService: context.read<PantryDeductionService>(),
              dietServingService: context.read<DietServingService>(),
              trackerProvider: context.read<TrackerProvider>(),
              authProvider: context.read<AuthController>(),
              pantryController: context.read<PantryController>(),
            ),
            update: (context, auth, pantry, tracker, recipeController) {
              recipeController!.authProvider = auth;
              recipeController.pantryController = pantry;
              return recipeController;
            },
          ),

          Provider<RouteObserver<ModalRoute<void>>>.value(value: routeObserver),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food RX',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      navigatorObservers: [routeObserver],
      home: Consumer<AuthController>(
        builder: (context, authController, _) {
          if (authController.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (authController.isAuthenticated) {
            return const MainScreen();
          }

          return const LoginPage();
        },
      ),
      routes: {
        '/signup': (context) => const SignupPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainScreen(),
        '/chatbot': (context) => const ChatbotPage(),
        '/meal-plan': (context) => const MealPlanPage(),
        '/diet-plan-viewer': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, String>;
          return DietPlanViewerPage(
            myPlanType: args['myPlanType']!,
            displayName: args['displayName']!,
          );
        },
        '/article-detail': (context) {
          final article = ModalRoute.of(context)!.settings.arguments as Article;
          return ArticleDetailPage(article: article);
        },
      },
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }
}
