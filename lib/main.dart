import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/auth/views/login_page.dart';
import 'package:flutter_app/features/auth/views/signup_page.dart';
import 'package:flutter_app/features/chatbot/views/chatbot_page.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/repositories/mongo_article_repository.dart';
import 'package:flutter_app/features/education/views/article_detail_page.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/pantry/providers/pantry_item_picker_provider.dart';
import 'package:flutter_app/features/pantry/repositories/ingredient_repository.dart';
import 'package:flutter_app/features/pantry/repositories/mongo_pantry_repository.dart';
import 'package:flutter_app/features/pantry/repositories/spoonacular_ingredient_repository.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/mongo_recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository_impl.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';
import 'package:flutter_app/features/recipes/services/cooking_service.dart';
import 'package:flutter_app/features/recipes/services/meal_logging_service.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/tracking/services/diet_plan_service.dart';
import 'package:flutter_app/features/tracking/services/tracker_service.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/image_cache_service.dart';
import 'package:flutter_app/features/home/providers/tip_provider.dart';
import 'package:flutter_app/features/home/services/tip_service.dart';
import 'package:flutter_app/features/chatbot/services/dialogflow_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/navigation/views/main_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  DialogflowService.initialize();

  runApp(
    MultiProvider(
      providers: [
        // Foundational Services (no external dependencies)
        Provider<MongoDBService>(create: (_) => MongoDBService()),
        Provider<UnitConversionService>(create: (_) => UnitConversionService()),
        Provider<ImageCacheService>(create: (_) => ImageCacheService()),
        Provider<DialogflowService>(create: (_) => DialogflowService()),
        Provider<DietPlanService>(create: (_) => DietPlanService()),
        Provider<SpoonacularRecipeRepository>(
            create: (_) => SpoonacularRecipeRepository()),
        Provider<SpoonacularIngredientRepository>(
            create: (_) => SpoonacularIngredientRepository()),

        // Dependent Services & Repositories
        ProxyProvider<UnitConversionService, FoodCategoryService>(
          update: (_, conversionService, __) =>
              FoodCategoryService(conversionService: conversionService),
        ),
        ProxyProvider<UnitConversionService, IngredientSubstitutionService>(
          update: (_, conversionService, __) => IngredientSubstitutionService(
              conversionService: conversionService),
        ),
        Provider<IngredientRepository>(
          create: (context) => context.read<SpoonacularIngredientRepository>(),
        ),
        ProxyProvider<MongoDBService, MongoPantryRepository>(
          update: (_, mongo, __) => MongoPantryRepository(mongo),
        ),
        ProxyProvider<MongoDBService, MongoArticleRepository>(
          update: (_, mongo, __) => MongoArticleRepository(mongo),
        ),
        ProxyProvider<MongoDBService, MongoRecipeRepository>(
          update: (_, mongo, __) => MongoRecipeRepository(mongo),
        ),
        ProxyProvider<MongoDBService, TipService>(
          update: (_, mongo, __) => TipService(mongo),
        ),
        Provider<TrackerService>(create: (_) => TrackerService()),
        ProxyProvider2<SpoonacularRecipeRepository, MongoRecipeRepository,
            RecipeRepository>(
          update: (_, spoonacular, mongo, __) =>
              RecipeRepositoryImpl(spoonacular, mongo) as RecipeRepository,
        ),

        // Auth Controller
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController()..initialize(),
        ),

        // UI-specific providers that depend on Auth
        ChangeNotifierProxyProvider<AuthController, TipProvider>(
          create: (context) => TipProvider(context.read<TipService>()),
          update: (context, auth, previous) => previous!,
        ),

        // App/generation services
        ProxyProvider<RecipeRepository, RecipeGenerationService>(
          update: (context, recipeRepo, __) => RecipeGenerationService(
            recipeRepository: recipeRepo,
            unitConversionService: context.read<UnitConversionService>(),
            foodCategoryService: context.read<FoodCategoryService>(),
            ingredientSubstitutionService:
                context.read<IngredientSubstitutionService>(),
          ),
        ),

        // Controllers & Services with complex dependencies
        ChangeNotifierProvider<TrackerProvider>(
          create: (_) => TrackerProvider(),
        ),

        ChangeNotifierProxyProvider<AuthController, PantryController>(
          create: (context) => PantryController(
            context.read<MongoDBService>(),
            conversionService: context.read<UnitConversionService>(),
            ingredientSubstitutionService:
                context.read<IngredientSubstitutionService>(),
          )..setAuthProvider(context.read<AuthController>()),
          update: (context, auth, previous) => previous!..setAuthProvider(auth),
        ),

        ChangeNotifierProxyProvider3<IngredientRepository, MongoDBService,
            AuthController, PantryItemPickerProvider>(
          create: (context) => PantryItemPickerProvider(
            context.read<IngredientRepository>(),
            context.read<MongoDBService>(),
            context.read<AuthController>(),
          ),
          update: (_, repo, mongo, auth, previous) => previous!,
        ),
        ProxyProvider3<TrackerService, TrackerProvider, DietPlanService,
            MealLoggingService>(
          update: (_, trackerService, trackerProvider, dietPlanService, __) =>
              MealLoggingService(
            trackerService: trackerService,
            trackerProvider: trackerProvider,
            dietPlanService: dietPlanService,
          ),
        ),
        ProxyProvider3<PantryController, RecipeRepository, MealLoggingService,
            CookingService>(
          update: (_, pantryController, recipeRepo, mealLoggingService, __) =>
              CookingService(
            pantryController: pantryController,
            recipeRepository: recipeRepo,
            mealLoggingService: mealLoggingService,
          ),
        ),

        ChangeNotifierProxyProvider2<AuthController, PantryController,
            RecipeController>(
          create: (context) => RecipeController(
            recipeGenerationService: context.read<RecipeGenerationService>(),
            recipeRepository: context.read<RecipeRepository>(),
            authProvider: context.read<AuthController>(),
            pantryController: context.read<PantryController>(),
            cookingService: context.read<CookingService>(),
            trackerProvider: context.read<TrackerProvider>(),
          ),
          update: (context, auth, pantry, previous) => previous!
            ..authProvider = auth
            ..pantryController = pantry,
        ),

        ChangeNotifierProxyProvider<AuthController, ArticleController>(
          create: (context) => ArticleController(
            context.read<MongoArticleRepository>(),
            context.read<AuthController>(),
          ),
          update: (context, auth, previous) => previous!..authProvider = auth,
        ),
        Provider<RouteObserver<ModalRoute<void>>>.value(value: routeObserver),
      ],
      child: const MyApp(),
    ),
  );
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
