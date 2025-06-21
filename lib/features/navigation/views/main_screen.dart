import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/views/home_page.dart';
import 'package:flutter_app/features/education/views/education_page.dart';
import 'package:flutter_app/features/navigation/widgets/custom_nav_bar.dart';
import 'package:flutter_app/features/pantry/views/pantry_page.dart';
import 'package:flutter_app/features/recipes/views/recipe_page.dart';
import 'package:flutter_app/features/navigation/widgets/add_action_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isAddActive = false;
  final List<Widget> _pages = [
    const HomePage(),
    const PantryPage(),
    const RecipePage(),
    const EducationPage(),
  ];

  void _handleAddTap() async {
    setState(() => _isAddActive = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddActionSheet(),
    );
    setState(() => _isAddActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: CustomNavBar(
              currentIndex: _currentIndex,
              onHomeTap: () => setState(() => _currentIndex = 0),
              onPantryTap: () => setState(() => _currentIndex = 1),
              onRecipeTap: () => setState(() => _currentIndex = 2),
              onEducationTap: () => setState(() => _currentIndex = 3),
              onChatTap: () {
                Navigator.pushNamed(context, '/chatbot');
              },
              isAddActive: _isAddActive,
              onAddTap: _handleAddTap,
            ),
          ),
        ),
      ),
    );
  }
}
