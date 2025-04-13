import 'package:flutter/material.dart';
import 'home_page.dart';
import 'education_page.dart';
import '../../widgets/custom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const SizedBox(), // Placeholder for chat (will be handled differently)
    const EducationPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: CustomNavBar(
          currentIndex: _currentIndex,
          onHomeTap: () {
            setState(() {
              _currentIndex = 0;
            });
          },
          onChatTap: () {
            Navigator.pushNamed(context, '/chatbot');
          },
          onEducationTap: () {
            setState(() {
              _currentIndex = 2;
            });
          },
        ),
      ),
    );
  }
}
