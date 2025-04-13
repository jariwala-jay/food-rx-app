import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/signup_provider.dart';
import 'services/mongodb_service.dart';
import 'views/pages/login_page.dart';
import 'views/pages/signup_page.dart';
import 'views/pages/main_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MongoDB service
  final mongoDBService = MongoDBService();
  await mongoDBService.initialize();

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
      ],
      child: const MyApp(),
    ),
  );
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
        '/chatbot': (context) => const Scaffold(
            body:
                Center(child: Text('Chat Bot'))), // Placeholder for chat screen
      },
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }
}
