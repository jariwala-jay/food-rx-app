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
import 'services/dialogflow_service.dart';
import 'scripts/setup_text_index.dart';
//import 'scripts/insert_tips.dart';
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

    // Set up text index for article search
    await setupTextIndex();

    // Initialize services
    final tipService = TipService(mongoDBService);

    // Insert initial tips
    //await insertTips();

    // Uncomment the line below to insert test articles
    //  await insertTestArticles();

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
            create: (_) => TipProvider(tipService),
          ),
          Provider<ArticleService>(
            create: (_) => ArticleService(mongoDBService),
          ),
          ChangeNotifierProxyProvider<AuthProvider, ArticleProvider>(
            create: (context) {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              final articleProvider = ArticleProvider(
                  Provider.of<ArticleService>(context, listen: false));
              articleProvider.setAuthProvider(authProvider);
              return articleProvider;
            },
            update: (context, authProvider, articleProvider) {
              final provider = articleProvider ??
                  ArticleProvider(
                      Provider.of<ArticleService>(context, listen: false));
              provider.setAuthProvider(authProvider);
              return provider;
            },
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
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
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (authProvider.isAuthenticated) {
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
