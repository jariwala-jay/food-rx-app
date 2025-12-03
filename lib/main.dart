import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/auth/views/login_page.dart';
import 'package:flutter_app/features/auth/views/signup_page.dart';
import 'package:flutter_app/features/auth/views/forgot_password_page.dart';
import 'package:flutter_app/features/auth/views/reset_password_page.dart';
import 'package:flutter_app/features/chatbot/views/chatbot_page.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/repositories/article_repository.dart';
import 'package:flutter_app/features/education/repositories/mongo_article_repository.dart';
import 'package:flutter_app/features/education/views/article_detail_page.dart';
import 'package:flutter_app/features/home/views/meal_plan_page.dart';
import 'package:flutter_app/features/home/views/diet_plan_viewer_page.dart';
import 'package:flutter_app/features/profile/views/profile_page.dart';
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
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/services/forced_tour_service.dart';
import 'package:flutter_app/features/chatbot/services/dialogflow_service.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/features/home/services/tip_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/features/navigation/views/main_screen.dart';
import 'package:flutter_app/core/services/navigation_service.dart';
import 'package:flutter_app/core/utils/app_logger.dart';
import 'package:app_links/app_links.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    DialogflowService.initialize();

    // Initialize Firebase first (before any Firebase services)
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('❌ Firebase initialization failed: $e');
      // Continue without Firebase - the app will use local notifications only
    }

    final mongoDBService = MongoDBService();
    await mongoDBService.initialize();

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Configure logging based on .env DEBUG
    AppLogger.enabled = (dotenv.env['DEBUG']?.toLowerCase() == 'true');

    // Register background message handler (both platforms)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Register ShowcaseView for guided tours
    ShowcaseView.register(
      onFinish: () {},
      autoPlay: false,
      enableAutoScroll: true,
      disableBarrierInteraction: true,
    );

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
          ChangeNotifierProvider(create: (_) => NotificationManager()),

          // Dependent Controllers (as ProxyProviders)
          ChangeNotifierProvider(
              create: (context) =>
                  TipProvider(TipService(context.read<MongoDBService>()))),

          // Forced Tour Provider
          ChangeNotifierProvider<ForcedTourProvider>(
            create: (context) => ForcedTourProvider(
              tourService: ForcedTourService(
                authController: context.read<AuthController>(),
              ),
            ),
          ),

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleInitialLink();
    _handleIncomingLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleInitialLink() async {
    // Handle deep links when app is opened from email
    // This will be called when app is opened via foodrx://reset-password?token=...
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }
  }

  void _handleIncomingLinks() {
    // Listen for deep links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Error handling incoming link: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    debugPrint('Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}, Query: ${uri.query}');
    
    // Check if it's a reset password link
    // Format: foodrx://reset-password?token=... or foodrx://?token=...
    if (uri.scheme == 'foodrx') {
      final token = uri.queryParameters['token'];
      
      // Check if it's a reset password link by host or path
      final isResetPassword = uri.host == 'reset-password' || 
                             uri.path.contains('reset-password') ||
                             token != null; // If token exists, assume it's reset password
      
      if (isResetPassword && token != null && token.isNotEmpty) {
        debugPrint('Navigating to reset password page with token');
        // Navigate to reset password page with token
        // Use addPostFrameCallback to ensure navigation happens after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), () {
            final navigator = NavigationService.navigatorKey.currentState;
            if (navigator != null) {
              // Clear navigation stack and go to login first, then to reset password
              // This ensures proper navigation stack
              navigator.pushNamedAndRemoveUntil(
                '/login',
                (route) => false, // Remove all previous routes
              );
              // Then navigate to reset password after a short delay
              Future.delayed(const Duration(milliseconds: 100), () {
                final currentNavigator = NavigationService.navigatorKey.currentState;
                if (currentNavigator != null) {
                  currentNavigator.pushNamed(
                    '/reset-password',
                    arguments: {'token': token},
                  );
                }
              });
            }
          });
        });
      } else {
        debugPrint('Reset password link missing token or invalid format');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food RX',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        dropdownMenuTheme: const DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(Colors.white),
          ),
        ),
      ),
      navigatorObservers: [routeObserver],
      home: Consumer<AuthController>(
        builder: (context, authController, _) {
          if (authController.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                ),
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
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/reset-password': (context) {
          // Try to get token from route arguments first
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          String? token = args?['token'] as String?;
          
          // If no token in arguments, try to get from query parameters
          if (token == null) {
            final route = ModalRoute.of(context);
            if (route != null && route.settings.name != null) {
              try {
                final uri = Uri.parse(route.settings.name!);
                token = uri.queryParameters['token'];
              } catch (e) {
                // If parsing fails, try to extract from the route name directly
                final routeName = route.settings.name ?? '';
                if (routeName.contains('token=')) {
                  final match = RegExp(r'token=([^&]+)').firstMatch(routeName);
                  token = match?.group(1);
                }
              }
            }
          }
          
          return ResetPasswordPage(token: token);
        },
        '/home': (context) => const MainScreen(),
        '/chatbot': (context) => const ChatbotPage(),
        '/meal-plan': (context) => const MealPlanPage(),
        '/diet-plan-viewer': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return DietPlanViewerPage(
            myPlanType: args['myPlanType'] as String,
            displayName: args['displayName'] as String,
            showGlycemicIndex: args['showGlycemicIndex'] as bool? ?? false,
          );
        },
        '/article-detail': (context) {
          final article = ModalRoute.of(context)!.settings.arguments as Article;
          return ArticleDetailPage(article: article);
        },
        '/profile': (context) => const ProfilePage(),
      },
      navigatorKey: NavigationService.navigatorKey,
    );
  }
}
