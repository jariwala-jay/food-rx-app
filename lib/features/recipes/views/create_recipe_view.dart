import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

class CreateRecipeView extends StatefulWidget {
  const CreateRecipeView({Key? key}) : super(key: key);

  @override
  State<CreateRecipeView> createState() => _CreateRecipeViewState();
}

class _CreateRecipeViewState extends State<CreateRecipeView> {
  final _formKey = GlobalKey<FormState>();
  final _servingsController = TextEditingController();
  final _cookingTimeHoursController = TextEditingController();
  final _cookingTimeMinutesController = TextEditingController();

  List<CuisineType> _selectedCuisines = [];
  MealType? _selectedMealType;
  String? _selectedMealTypeName; // Track the display name separately
  int? _servings;
  int? _cookingTimeHours;
  int? _cookingTimeMinutes;

  // Preset cooking time chips (minutes)
  static const List<int> _presetCookingTimes = [15, 30, 60];
  int? _selectedPresetMinutes;
  bool _useCustomCookingTime = false;

  // Popular cuisines that are commonly selected
  static const List<CuisineType> _popularCuisines = [
    CuisineType.american,
    CuisineType.italian,
    CuisineType.mexican,
    CuisineType.chinese,
    CuisineType.indian,
    CuisineType.japanese,
    CuisineType.mediterranean,
    CuisineType.thai,
    CuisineType.french,
    CuisineType.korean,
  ];

  @override
  void initState() {
    super.initState();
    _prepopulateForm();
  }

  void _prepopulateForm() {
    // Get user data for prepopulation
    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;

    if (user != null) {
      // Prepopulate cuisines based on user's favorite cuisines
      _selectedCuisines =
          _mapUserCuisinesToCuisineTypes(user.favoriteCuisines ?? []);

      // Prepopulate servings based on user's cooking preferences
      final cookingForPeople = user.cookingForPeople;
      if (cookingForPeople != null && cookingForPeople.isNotEmpty) {
        _servingsController.text = cookingForPeople;
        _servings = int.tryParse(cookingForPeople);
      } else {
        _servingsController.text = '1';
        _servings = 1;
      }

      // Prepopulate cooking time based on user's preferred meal prep time
      _prepopulateCookingTime(user.preferredMealPrepTime);

      // Set default meal type based on current time
      final now = DateTime.now();
      final hour = now.hour;

      if (hour >= 6 && hour < 11) {
        _selectedMealType = MealType.breakfast;
        _selectedMealTypeName = 'Breakfast';
      } else if (hour >= 11 && hour < 16) {
        _selectedMealType = MealType.mainCourse; // Lunch
        _selectedMealTypeName = 'Lunch';
      } else if (hour >= 16 && hour < 22) {
        _selectedMealType = MealType.mainCourse; // Dinner
        _selectedMealTypeName = 'Dinner';
      } else {
        _selectedMealType = MealType.snack;
        _selectedMealTypeName = 'Snacks';
      }
    }
  }

  @override
  void dispose() {
    _servingsController.dispose();
    _cookingTimeHoursController.dispose();
    _cookingTimeMinutesController.dispose();
    super.dispose();
  }

  /// Maps user's favorite cuisines (strings) to CuisineType enums
  List<CuisineType> _mapUserCuisinesToCuisineTypes(List<String> userCuisines) {
    final Map<String, CuisineType> cuisineMap = {
      'American': CuisineType.american,
      'Mexican': CuisineType.mexican,
      'Italian': CuisineType.italian,
      'Chinese': CuisineType.chinese,
      'Indian': CuisineType.indian,
      'French': CuisineType.french,
      'Thai': CuisineType.thai,
      'Japanese': CuisineType.japanese,
      'Mediterranean': CuisineType.mediterranean,
      'Korean': CuisineType.korean,
    };

    return userCuisines
        .where((cuisine) => cuisineMap.containsKey(cuisine))
        .map((cuisine) => cuisineMap[cuisine]!)
        .toList();
  }

  /// Prepopulates cooking time based on user's preferred meal prep time
  void _prepopulateCookingTime(String? preferredMealPrepTime) {
    if (preferredMealPrepTime == null) return;

    switch (preferredMealPrepTime) {
      case 'Up to 15 minutes':
        _cookingTimeHours = 0;
        _cookingTimeMinutes = 15;
        break;
      case 'Up to 30 minutes':
        _cookingTimeHours = 0;
        _cookingTimeMinutes = 30;
        break;
      case 'Up to one hour':
        _cookingTimeHours = 1;
        _cookingTimeMinutes = 0;
        break;
      default:
        // Default to 30 minutes if no match
        _cookingTimeHours = 0;
        _cookingTimeMinutes = 30;
    }

    // Update the text controllers
    _cookingTimeHoursController.text = _cookingTimeHours?.toString() ?? '';
    _cookingTimeMinutesController.text =
        _cookingTimeMinutes?.toString().padLeft(2, '0') ?? '';

    // Try to match a preset, otherwise default to Custom
    final total = ((_cookingTimeHours ?? 0) * 60) + (_cookingTimeMinutes ?? 0);
    if (_presetCookingTimes.contains(total)) {
      _selectedPresetMinutes = total;
      _useCustomCookingTime = false;
    } else {
      _selectedPresetMinutes = null;
      _useCustomCookingTime = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Recipe',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Cuisines'),
                      const SizedBox(height: 12),
                      _buildCuisineSelector(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Meal Type'),
                      const SizedBox(height: 12),
                      _buildMealTypeSelector(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Servings'),
                      const SizedBox(height: 12),
                      _buildServingsInput(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Estimated Cooking Time'),
                      const SizedBox(height: 12),
                      _buildCookingTimeInput(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _buildGenerateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildCuisineSelector() {
    return GestureDetector(
      onTap: _showCuisineSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCuisines.isEmpty
                    ? 'Select Cuisines'
                    : _selectedCuisines.map((c) => c.displayName).join(', '),
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedCuisines.isEmpty
                      ? Colors.grey[600]
                      : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return GestureDetector(
      onTap: _showMealTypeSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedMealTypeName ?? 'Select Meal Type',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedMealType == null
                      ? Colors.grey[600]
                      : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServingsInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: TextFormField(
        controller: _servingsController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'e.g., 4',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
        onChanged: (value) {
          _servings = int.tryParse(value);
        },
      ),
    );
  }

  Widget _buildCookingTimeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presetCookingTimes.map((minutes) {
                final isSelected =
                    _selectedPresetMinutes == minutes && !_useCustomCookingTime;
                return _buildTimeChip(
                  label: _formatMinutesLabel(minutes),
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedPresetMinutes = minutes;
                      _useCustomCookingTime = false;
                      _cookingTimeHours = minutes ~/ 60;
                      _cookingTimeMinutes = minutes % 60;
                      _cookingTimeHoursController.text =
                          _cookingTimeHours.toString();
                      _cookingTimeMinutesController.text =
                          (_cookingTimeMinutes ?? 0).toString().padLeft(2, '0');
                    });
                  },
                );
              }).toList(),
              _buildTimeChip(
                label: 'Custom',
                isSelected: _useCustomCookingTime,
                onTap: () {
                  setState(() {
                    _useCustomCookingTime = true;
                    _selectedPresetMinutes = null;
                  });
                },
              ),
            ],
          ),
        ),
        if (_useCustomCookingTime) const SizedBox(height: 12),
        if (_useCustomCookingTime)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cookingTimeHoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'HH',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedPresetMinutes = null;
                        _useCustomCookingTime = true;
                        _cookingTimeHours = int.tryParse(value);
                      });
                    },
                  ),
                ),
                const Text(
                  ':',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _cookingTimeMinutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'MM',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedPresetMinutes = null;
                        _useCustomCookingTime = true;
                        final parsed = int.tryParse(value) ?? 0;
                        // Clamp minutes to 0-59 for sanity
                        _cookingTimeMinutes = parsed.clamp(0, 59);
                        _cookingTimeMinutesController.text =
                            _cookingTimeMinutes!.toString().padLeft(2, '0');
                        _cookingTimeMinutesController.selection =
                            TextSelection.fromPosition(
                          TextPosition(
                              offset:
                                  _cookingTimeMinutesController.text.length),
                        );
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.access_time, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatMinutesLabel(int minutes) {
    if (minutes == 60) return '1hr';
    if (minutes == 30) return '30mn';
    if (minutes == 15) return '15m';
    // Fallbacks (should not be hit with current presets)
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return hours == 1 ? '1hr' : '${hours}hr';
    return '${hours}hr ${mins}m';
  }

  Widget _buildTimeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const color = Color(0xFFFF6A00);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Consumer<RecipeController>(
        builder: (context, controller, child) {
          return ElevatedButton(
            onPressed: controller.isLoading ? null : _generateRecipe,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: controller.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Generate Recipe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _showCuisineSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Cuisines',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _popularCuisines.length,
                itemBuilder: (context, index) {
                  final cuisine = _popularCuisines[index];

                  return StatefulBuilder(
                    builder: (context, setStateNew) {
                      final isSelected = _selectedCuisines.contains(cuisine);

                      return CheckboxListTile(
                        title: Text(cuisine.displayName),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setStateNew(() {
                            if (value == true) {
                              if (!_selectedCuisines.contains(cuisine)) {
                                _selectedCuisines.add(cuisine);
                              }
                            } else {
                              _selectedCuisines.remove(cuisine);
                            }
                          });
                          // Also update the main widget state
                          setState(() {});
                        },
                        activeColor: const Color(0xFFFF6A00),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMealTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Select Meal Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            ..._getSimplifiedMealTypeOptions().map((option) => ListTile(
                  title: Text(option['name']),
                  onTap: () {
                    setState(() {
                      _selectedMealType = option['mealType'];
                      _selectedMealTypeName = option['name'];
                    });
                    Navigator.pop(context);
                  },
                  trailing: _selectedMealTypeName == option['name']
                      ? const Icon(Icons.check, color: Color(0xFFFF6A00))
                      : null,
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSimplifiedMealTypeOptions() {
    return [
      {
        'name': 'Breakfast',
        'mealType': MealType.breakfast,
        'spoonacularTypes': ['breakfast']
      },
      {
        'name': 'Lunch',
        'mealType': MealType.mainCourse,
        'spoonacularTypes': ['main course', 'salad', 'soup']
      },
      {
        'name': 'Dinner',
        'mealType': MealType.mainCourse,
        'spoonacularTypes': [
          'main course',
          'side dish',
          'appetizer',
          'salad',
          'soup'
        ]
      },
      {
        'name': 'Snacks',
        'mealType': MealType.snack,
        'spoonacularTypes': ['snack', 'fingerfood']
      },
      {
        'name': 'Desserts',
        'mealType': MealType.dessert,
        'spoonacularTypes': ['dessert']
      },
      {
        'name': 'Beverages',
        'mealType': MealType.beverage,
        'spoonacularTypes': ['beverage', 'drink']
      },
    ];
  }

  /// Maps user-facing meal type selection to Spoonacular API meal types
  List<String>? _getSpoonacularMealTypes(String? mealTypeName) {
    if (mealTypeName == null) return null;

    switch (mealTypeName) {
      case 'Breakfast':
        return ['breakfast'];
      case 'Lunch':
        return ['main course', 'salad', 'soup'];
      case 'Dinner':
        return ['main course', 'side dish', 'appetizer', 'salad', 'soup'];
      case 'Snacks':
        return ['snack', 'fingerfood'];
      case 'Desserts':
        return ['dessert'];
      case 'Beverages':
        return ['beverage', 'drink'];
      default:
        return ['main course']; // Default fallback
    }
  }

  void _generateRecipe() async {
    // Calculate total cooking time in minutes
    int? totalMinutes;
    if (_cookingTimeHours != null || _cookingTimeMinutes != null) {
      totalMinutes =
          ((_cookingTimeHours ?? 0) * 60) + (_cookingTimeMinutes ?? 0);
    }

    // Get user profile for intelligent filtering
    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;

    // Determine diet compliance based on user profile
    bool dashCompliant = false;
    bool myPlateCompliant = false;

    if (user != null) {
      final medicalConditions = user.medicalConditions ?? [];
      final healthGoals = user.healthGoals;

      // Auto-detect diet type based on medical conditions and health goals
      if (user.dietType == 'DASH' ||
          medicalConditions.contains('Hypertension') ||
          healthGoals.contains('Lower blood pressure')) {
        dashCompliant = true;
      } else {
        myPlateCompliant = true;
      }
    }

    // Create filter with user selections and intelligent defaults
    // Map the user-facing meal type to the appropriate Spoonacular meal types
    final spoonacularMealTypes =
        _getSpoonacularMealTypes(_selectedMealTypeName);

    final filter = RecipeFilter(
      cuisines: _selectedCuisines,
      mealType: _selectedMealType, // This will be used internally
      spoonacularMealTypes:
          spoonacularMealTypes, // This will be used for Spoonacular API
      servings: _servings,
      maxReadyTime: totalMinutes,
      includeIngredients: true,
      prioritizeExpiring: true,
      dashCompliant: dashCompliant,
      myPlateCompliant: myPlateCompliant,
      veryHealthy: true, // Always prefer healthier options
    );

    // Add debug information about meal type mapping
    if (kDebugMode) {
      print('  User Selection: $_selectedMealTypeName');
      print('  Spoonacular Types: $spoonacularMealTypes');
      print('  Internal MealType: $_selectedMealType');
    }

    if (kDebugMode) {}

    // Get controller and generate recipes
    final controller = Provider.of<RecipeController>(context, listen: false);

    // Start generation and navigate to Recipe tab
    controller.generateRecipes(filter: filter);

    if (!mounted) return;

    // Pop back to MainScreen - the Recipe tab is already selected
    Navigator.of(context).pop();

    // Wait for recipes to be generated, then trigger showcase
    // Poll for recipes with increasing delays
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (controller.recipes.isNotEmpty) {
        try {
          ShowcaseView.get().startShowCase([TourKeys.recipesKey]);
        } catch (e) {}
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (controller.recipes.isNotEmpty) {
        try {
          ShowcaseView.get().startShowCase([TourKeys.recipesKey]);
        } catch (e) {}
      }
    });

    // Show feedback with diet-specific information
    final dietInfo = dashCompliant
        ? 'DASH diet'
        : myPlateCompliant
            ? 'MyPlate guidelines'
            : 'your preferences';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating recipes based on $dietInfo...'),
        backgroundColor: Colors.orange,
        duration: const Duration(milliseconds: 800),
      ),
    );
  }
}
