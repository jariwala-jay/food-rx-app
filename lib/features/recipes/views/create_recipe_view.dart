import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

class CreateRecipeView extends StatefulWidget {
  const CreateRecipeView({Key? key}) : super(key: key);

  @override
  State<CreateRecipeView> createState() => _CreateRecipeViewState();
}

class _CreateRecipeViewState extends State<CreateRecipeView> {
  final _formKey = GlobalKey<FormState>();
  final _servingsController = TextEditingController();
  final _cookingTimeController = TextEditingController();

  final List<CuisineType> _selectedCuisines = [];
  MealType? _selectedMealType;
  int? _servings;
  int? _cookingTimeHours;
  int? _cookingTimeMinutes;

  @override
  void initState() {
    super.initState();
    // The RecipeController is now initialized globally or on the main RecipePage.
    // We don't need to re-initialize it here.
  }

  @override
  void dispose() {
    _servingsController.dispose();
    _cookingTimeController.dispose();
    super.dispose();
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
                _selectedMealType?.displayName ?? 'Select Meal Type',
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
    return Container(
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
                _cookingTimeHours = int.tryParse(value);
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
                _cookingTimeMinutes = int.tryParse(value);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.access_time, color: Colors.grey),
            onPressed: () {
              // Could show time picker here
            },
          ),
        ],
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
                itemCount: CuisineType.values.length,
                itemBuilder: (context, index) {
                  final cuisine = CuisineType.values[index];
                  final isSelected = _selectedCuisines.contains(cuisine);

                  return CheckboxListTile(
                    title: Text(cuisine.displayName),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedCuisines.add(cuisine);
                        } else {
                          _selectedCuisines.remove(cuisine);
                        }
                      });
                    },
                    activeColor: const Color(0xFFFF6A00),
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
            ...MealType.values.map((mealType) => ListTile(
                  title: Text(mealType.displayName),
                  onTap: () {
                    setState(() {
                      _selectedMealType = mealType;
                    });
                    Navigator.pop(context);
                  },
                  trailing: _selectedMealType == mealType
                      ? const Icon(Icons.check, color: Color(0xFFFF6A00))
                      : null,
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
    final filter = RecipeFilter(
      cuisines: _selectedCuisines,
      mealType: _selectedMealType,
      servings: _servings,
      maxReadyTime: totalMinutes,
      includeIngredients: true,
      prioritizeExpiring: true,
      dashCompliant: dashCompliant,
      myPlateCompliant: myPlateCompliant,
      veryHealthy: true, // Always prefer healthier options
    );

    if (kDebugMode) {
      print('🎯 CreateRecipeView: Starting recipe generation...');
    }

    // Get controller and generate recipes
    final controller = Provider.of<RecipeController>(context, listen: false);

    // Start generation and navigate back immediately
    controller.generateRecipes(filter: filter);

    if (!mounted) return;
    Navigator.pop(context);

    // Show feedback with diet-specific information
    final dietInfo = dashCompliant ? 'DASH diet' : myPlateCompliant ? 'MyPlate guidelines' : 'your preferences';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating recipes based on $dietInfo...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDebugInfo(BuildContext context, RecipeController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User ID: ${controller.currentUser?.id ?? 'Not loaded'}'),
                const SizedBox(height: 8),
                Text('Pantry Items Count: ${controller.pantryItems.length}'),
                const SizedBox(height: 8),
                Text('Is Loading: ${controller.isLoading}'),
                const SizedBox(height: 8),
                Text('Error: ${controller.error ?? 'None'}'),
                const SizedBox(height: 16),
                const Text('Pantry Items:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (controller.pantryItems.isEmpty)
                  const Text('No pantry items found')
                else
                  ...controller.pantryItems.take(20).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${item.name} (${item.quantity} ${item.unitLabel}) - isPantryItem: ${item.isPantryItem}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )),
                if (controller.pantryItems.length > 20)
                  Text(
                      '... and ${controller.pantryItems.length - 20} more items'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              controller.refreshPantryItems();
              Navigator.pop(context);
            },
            child: const Text('Refresh & Close'),
          ),
        ],
      ),
    );
  }
}
