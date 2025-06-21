# Gemini 2.5 Recipe Adjustment Integration

This integration adds AI-powered recipe adjustment capabilities to the Food Precision Rx app using Google's Gemini 2.5 Pro Preview model.

## Features

- **Multi-recipe adjustment**: Process multiple recipes in a single API call
- **Intelligent ingredient substitutions**: Replace missing ingredients with available pantry items
- **Serving size scaling**: Automatically scale recipes to desired serving sizes
- **Missing ingredient analysis**: Mark recipes as skipped if essential ingredients are unavailable
- **Instruction rewriting**: Update cooking instructions to reflect changes
- **Confidence scoring**: Each adjustment includes a confidence score (0.0-1.0)
- **Caching**: Prevents redundant API calls with intelligent caching
- **Fallback handling**: Graceful degradation when API is unavailable

## Setup

### 1. API Key Configuration

1. Get a free Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a `.env` file in your project root (it's already gitignored)
3. Add your API key:

```env
# Google Gemini API Key (Free Tier - Gemini 2.5 Pro Preview)
GEMINI_API_KEY=your_gemini_api_key_here

# Your existing keys
SPOONACULAR_API_KEY=your_spoonacular_api_key_here
MONGODB_CONNECTION_STRING=your_mongodb_connection_string_here
```

### 2. Install Dependencies

The required dependency `google_generative_ai` has already been added to `pubspec.yaml`. Run:

```bash
flutter pub get
```

### 3. Add Provider to App

In your `main.dart`, add the GeminiRecipeProvider:

```dart
import 'package:provider/provider.dart';
import 'lib/providers/gemini_recipe_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => GeminiRecipeProvider()),
        // ... your existing providers
      ],
      child: MyApp(),
    ),
  );
}
```

## Usage

### Basic Recipe Adjustment

```dart
import 'package:provider/provider.dart';

// In your widget or controller
final geminiProvider = context.read<GeminiRecipeProvider>();
final pantryProvider = context.read<PantryProvider>(); // Your existing provider

await geminiProvider.adjustRecipes(
  recipes: spoonacularRecipes,           // List<Recipe> from Spoonacular
  pantryItems: pantryProvider.pantryItems, // List<PantryItem> from user's pantry
  targetServings: 4,                     // Desired serving size
);

// Check results
if (geminiProvider.hasResults) {
  final adjustedRecipes = geminiProvider.adjustedRecipes;
  final skippedRecipes = geminiProvider.skippedRecipes;
  // Use in your UI
}
```

### Integration with Existing Recipe Flow

```dart
// Example: Replace your existing recipe search with AI-adjusted results
Future<List<Recipe>> getAdjustedRecipes({
  required String searchQuery,
  required List<PantryItem> pantryItems,
  required int targetServings,
}) async {
  final spoonacularService = SpoonacularService();
  final geminiProvider = context.read<GeminiRecipeProvider>();
  
  // 1. Get recipes from Spoonacular
  final searchParams = <String, String>{
    'query': searchQuery,
    'includeIngredients': pantryItems.map((item) => item.name).join(','),
    'number': '20',
    'addRecipeInformation': 'true',
    'fillIngredients': 'true',
  };
  
  final recipeResults = await spoonacularService.searchRecipes(searchParams);
  if (recipeResults == null || recipeResults['results'] == null) {
    return [];
  }
  
  // Convert to Recipe objects
  final spoonacularRecipes = <Recipe>[];
  for (var recipeData in recipeResults['results']) {
    spoonacularRecipes.add(Recipe.fromJson(recipeData));
  }
  
  // 2. Adjust with Gemini
  await geminiProvider.adjustRecipes(
    recipes: spoonacularRecipes,
    pantryItems: pantryItems,
    targetServings: targetServings,
  );
  
  // 3. Return adjusted recipes or fallback to original
  if (geminiProvider.hasResults) {
    return GeminiRecipeUtils.convertAdjustedRecipesToRecipes(
      geminiProvider.adjustedRecipes
    );
  }
  
  return spoonacularRecipes; // Fallback
}
```

### Custom Adjustment Settings

```dart
final customSettings = GeminiAdjustmentSettings(
  allowIngredientSubstitutions: true,        // Allow substitutions
  skipRecipesWithMissingEssentials: false,   // Try to adjust everything
  preserveNutritionalBalance: true,          // Maintain nutrition
  dietaryRestrictions: ['vegetarian'],       // Respect dietary needs
  substitutionTolerance: 0.8,               // Liberal substitutions (0.0-1.0)
);

await geminiProvider.adjustRecipes(
  recipes: recipes,
  pantryItems: pantryItems,
  targetServings: 6,
  customSettings: customSettings,
);
```

### UI Integration

```dart
// Example widget showing adjusted recipes
Widget buildRecipeList() {
  return Consumer<GeminiRecipeProvider>(
    builder: (context, geminiProvider, child) {
      if (geminiProvider.isLoading) {
        return const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Adjusting recipes with AI...'),
            ],
          ),
        );
      }

      if (geminiProvider.error != null) {
        return Center(
          child: Column(
            children: [
              Icon(Icons.error, color: Colors.red),
              Text('Error: ${geminiProvider.error}'),
              ElevatedButton(
                onPressed: () => geminiProvider.clearResults(),
                child: Text('Try Again'),
              ),
            ],
          ),
        );
      }

      if (!geminiProvider.hasResults) {
        return const Center(child: Text('No recipes available'));
      }

      return ListView.builder(
        itemCount: geminiProvider.adjustedRecipes.length,
        itemBuilder: (context, index) {
          final adjustedRecipe = geminiProvider.adjustedRecipes[index];
          return RecipeCard(recipe: adjustedRecipe.adjustedRecipe);
        },
      );
    },
  );
}
```

## Data Models

### Input Models

- **GeminiRecipeInput**: Contains recipes, pantry items, target servings, and settings
- **GeminiAdjustmentSettings**: Configuration for how adjustments should be made

### Output Models

- **GeminiRecipeOutput**: Complete response with adjusted recipes, skipped recipes, and processing summary
- **AdjustedRecipe**: Contains original recipe, adjusted recipe, and all changes made
- **IngredientAdjustment**: Details about ingredient substitutions or scaling
- **InstructionAdjustment**: Details about instruction modifications
- **ServingAdjustment**: Details about serving size changes

## Utility Functions

The `GeminiRecipeUtils` class provides helpful utilities:

```dart
// Convert adjusted recipes to regular recipes for UI
final recipes = GeminiRecipeUtils.convertAdjustedRecipesToRecipes(adjustedRecipes);

// Get only high-confidence adjustments
final goodRecipes = GeminiRecipeUtils.getSuccessfullyAdjustedRecipes(output);

// Analyze pantry coverage
final coverage = GeminiRecipeUtils.analyzePantryCoverage(recipes, pantryItems);

// Create detailed adjustment report
final report = GeminiRecipeUtils.createAdjustmentReport(output);
```

## Error Handling

The integration includes comprehensive error handling:

1. **API Key Missing**: Falls back to original recipes with warning
2. **Network Errors**: Graceful degradation with error messages
3. **Invalid Input**: Validation with helpful error messages
4. **Response Parsing**: Fallback responses for malformed JSON
5. **Service Initialization**: Clear status indicators

## Performance Considerations

- **Caching**: Results are cached to prevent redundant API calls
- **Batch Processing**: Multiple recipes processed in single API call
- **Token Limits**: Configured for 8192 tokens to handle large recipe batches
- **Rate Limiting**: Built into Google's free tier (no additional handling needed)

## Monitoring and Analytics

Access processing statistics:

```dart
final stats = geminiProvider.getAdjustmentStats();
// Returns: processing time, success rate, etc.

final substitutions = geminiProvider.getSubstitutionsSummary();
// Returns: list of all ingredient substitutions made

final serviceInfo = geminiProvider.getServiceInfo();
// Returns: initialization status, cache size, etc.
```

## Troubleshooting

### Common Issues

1. **"Gemini service not initialized"**
   - Check that `GEMINI_API_KEY` is set in `.env`
   - Verify the API key is valid

2. **"No response received from Gemini"**
   - Check internet connectivity
   - Verify API key permissions
   - Check Gemini service status

3. **Low confidence scores**
   - Review pantry item quality/names
   - Check recipe complexity
   - Consider adjusting substitution tolerance

4. **Many recipes skipped**
   - Increase substitution tolerance
   - Set `skipRecipesWithMissingEssentials: false`
   - Review essential ingredient definitions

### Debug Information

Enable detailed logging:

```dart
import 'dart:developer' as developer;

// The service automatically logs processing steps
// Check your debug console for detailed information
```

## Free Tier Limits

Google's Gemini free tier includes:
- 15 requests per minute
- 1 million tokens per minute
- 1500 requests per day

The integration is optimized for these limits by:
- Batching multiple recipes per request
- Caching results to avoid redundant calls
- Using efficient prompts to minimize token usage

## Next Steps

1. Test the integration with your existing recipe flow
2. Customize adjustment settings for your use case
3. Add UI elements to show adjustment details
4. Monitor usage and adjust caching strategies
5. Consider upgrading to paid tier for higher limits if needed

For examples and advanced usage, see `lib/examples/gemini_recipe_integration_example.dart`. 