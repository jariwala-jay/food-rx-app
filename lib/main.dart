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
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/pantry/repositories/ingredient_repository.dart';
import 'package:flutter_app/features/pantry/repositories/spoonacular_ingredient_repository.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart'
    as domain_repo;
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
import 'package:flutter_app/features/home/services/tip_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
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
          // Core providers and services
          ChangeNotifierProvider(create: (_) => AuthController()..initialize()),
          ChangeNotifierProvider(create: (_) => SignupProvider()),
          Provider<MongoDBService>(create: (_) => mongoDBService),
          ChangeNotifierProvider(
              create: (context) =>
                  TipProvider(TipService(context.read<MongoDBService>()))),
          ChangeNotifierProvider(create: (_) => TrackerProvider()),
          Provider<UnitConversionService>(
              create: (_) => UnitConversionService()),
          Provider<FoodCategoryService>(
              create: (context) => FoodCategoryService(
                  conversionService: context.read<UnitConversionService>())),
          Provider<IngredientSubstitutionService>(
              create: (context) => IngredientSubstitutionService(
                  conversionService: context.read<UnitConversionService>())),

          // Feature-specific Repositories
          Provider<ArticleRepository>(
            create: (context) =>
                MongoArticleRepository(context.read<MongoDBService>()),
          ),
          Provider<SpoonacularRecipeRepository>(
            create: (_) => SpoonacularRecipeRepository(),
          ),
          Provider<MongoRecipeRepository>(
            create: (context) =>
                MongoRecipeRepository(context.read<MongoDBService>()),
          ),
          Provider<domain_repo.RecipeRepository>(
            create: (context) => RecipeRepositoryImpl(
              context.read<SpoonacularRecipeRepository>(),
              context.read<MongoRecipeRepository>(),
            ),
          ),
          Provider<IngredientRepository>(
            create: (context) => SpoonacularIngredientRepository(),
          ),

          // Feature Controllers (as ProxyProviders where they depend on auth state)
          ChangeNotifierProxyProvider<AuthController, PantryController>(
            create: (context) => PantryController(
              context.read<MongoDBService>(),
              conversionService: context.read<UnitConversionService>(),
              ingredientSubstitutionService:
                  context.read<IngredientSubstitutionService>(),
            ),
            update: (context, auth, pantry) {
              final controller = pantry ??
                  PantryController(
                    context.read<MongoDBService>(),
                    conversionService: context.read<UnitConversionService>(),
                    ingredientSubstitutionService:
                        context.read<IngredientSubstitutionService>(),
                  );
              if (auth.isAuthenticated && auth.currentUser?.id != null) {
                controller.setAuthProvider(auth);
                controller.initializeWithUser(auth.currentUser!.id!);
              }
              return controller;
            },
          ),

          ChangeNotifierProxyProvider<AuthController, ArticleController>(
            create: (context) => ArticleController(
              context.read<ArticleRepository>(),
              context.read<AuthController>(),
            ),
            update: (context, auth, articleController) {
              final controller = articleController ??
                  ArticleController(context.read<ArticleRepository>(), auth);
              controller.initialize();
              return controller;
            },
          ),

          ChangeNotifierProxyProvider2<AuthController, PantryController,
              RecipeController>(
            create: (context) => RecipeController(
              recipeGenerationService: RecipeGenerationService(
                recipeRepository: context.read<domain_repo.RecipeRepository>(),
                unitConversionService: context.read<UnitConversionService>(),
                foodCategoryService: context.read<FoodCategoryService>(),
                ingredientSubstitutionService:
                    context.read<IngredientSubstitutionService>(),
              ),
              recipeRepository: context.read<domain_repo.RecipeRepository>(),
              authProvider: context.read<AuthController>(),
              pantryController: context.read<PantryController>(),
            ),
            update: (context, auth, pantry, recipeController) {
              final controller = recipeController!;
              controller.authProvider = auth;
              controller.pantryController = pantry;
              return controller;
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
        '/article-detail': (context) {
          final article = ModalRoute.of(context)!.settings.arguments as Article;
          return ArticleDetailPage(article: article);
        },
      },
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }
}
