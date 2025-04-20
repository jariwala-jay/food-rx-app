import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/signup_provider.dart';
import 'providers/article_provider.dart';
import 'providers/tip_provider.dart';
import 'services/mongodb_service.dart';
import 'services/article_service.dart';
import 'services/tip_service.dart';
import 'views/pages/login_page.dart';
import 'views/pages/signup_page.dart';
import 'views/pages/main_screen.dart';
import 'views/pages/chatbot_page.dart';
import 'views/pages/article_detail_page.dart';
import 'models/article.dart';
import 'services/auth_service.dart';
import 'scripts/insert_tips.dart';
import 'services/dialogflow_service.dart';
//import 'scripts/insert_test_articles.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize DialogflowService
    DialogflowService.initialize();

    // Initialize MongoDB service
    final mongoDBService = MongoDBService();
    await mongoDBService.initialize();

    // Initialize services
    final articleService = ArticleService(mongoDBService);
    final tipService = TipService(mongoDBService.db);

    // Check if tips exist in database
    final tips = await tipService.getAllTips();
    print('Number of tips in database: ${tips.length}');
    if (tips.isEmpty) {
      print('No tips found in database. Inserting tips...');
      await insertTips();
      final newTips = await tipService.getAllTips();
      print('Number of tips after insertion: ${newTips.length}');
    }

    // Insert initial tips
    //await insertTips();

    // Uncomment the line below to insert test articles
    //await insertTestArticles();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider()..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => SignupProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthService(),
          ),
          ChangeNotifierProvider(
            create: (_) => TipProvider(tipService),
          ),
          ChangeNotifierProxyProvider<AuthProvider, ArticleProvider>(
            create: (context) => ArticleProvider(
              articleService,
              context.read<AuthProvider>(),
            ),
            update: (context, authProvider, articleProvider) =>
                ArticleProvider(articleService, authProvider),
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Error during initialization: $e');
    rethrow;
  }
}

//stateful
//Material App

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
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          print(
              'Auth state changed - isAuthenticated: ${authProvider.isAuthenticated}, isLoading: ${authProvider.isLoading}, currentUser: ${authProvider.currentUser?.id}');

          if (authProvider.isLoading) {
            print('Showing loading screen');
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (authProvider.isAuthenticated) {
            print('User is authenticated, showing MainScreen');
            return const MainScreen();
          }

          print('User is not authenticated, showing LoginPage');
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
