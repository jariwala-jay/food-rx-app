/// Nutrition / lifestyle glossary for chatbot tap-to-define highlights.
///
/// [highlightPriority]: higher scores are preferred when at most
/// [maxHighlightsPerMessage] terms are highlighted per assistant reply.
/// Terms omitted from the map use [highlightPriorityDefault] (low noise).
class ChatbotGlossary {
  /// At most this many glossary terms are link-highlighted per bot message.
  static const int maxHighlightsPerMessage = 2;

  /// Default priority when a term is not listed in [highlightPriority].
  static const int highlightPriorityDefault = 5;

  /// Bonus added when this canonical has not yet received a **prime** in the chat session.
  static const double noveltyScoreBonus = 1.5;

  /// Caps raw condition boost before blending so personalization cannot swamp base priority.
  static const int maxConditionBoostForBlend = 15;

  /// Optional: at most one **prime** per group id per message (related terms compete).
  /// Canonicals omitted here are only limited by overlap / max primes, not by group.
  static const Map<String, String> semanticPrimeGroup = {
    'blood sugar': 'glucose_metabolism',
    'blood glucose': 'glucose_metabolism',
    'glycemic index': 'glucose_metabolism',
    'glycemic load': 'glucose_metabolism',
    'hba1c': 'glucose_metabolism',
    'fasting blood sugar': 'glucose_metabolism',
    'low gi': 'glucose_metabolism',
    'insulin': 'glucose_metabolism',
    'insulin resistance': 'glucose_metabolism',
    'simple carbs': 'glucose_metabolism',
    'complex carbs': 'glucose_metabolism',
  };

  /// Blend base glossary priority with condition boost: keeps personalization from dominating.
  static double combinedHighlightScore({
    required int baseScore,
    required int conditionBoostRaw,
    required bool isNovel,
  }) {
    final b = baseScore.clamp(0, 500).toDouble();
    final cb =
        conditionBoostRaw.clamp(0, maxConditionBoostForBlend).toDouble();
    var s = 0.7 * b + 0.3 * cb;
    if (isNovel) {
      s += noveltyScoreBonus;
    }
    return s;
  }

  /// Higher number = more likely to receive a highlight slot (max 2 per reply).
  static const Map<String, int> highlightPriority = {
    // Core product concepts (must win)
    'diabetes plate': 100,
    'myplate': 97,
    'dash diet': 97,

    // Core diabetes management metric
    'hba1c': 94,

    // High-value health concepts
    'glycemic index': 96,
    'glycemic load': 95,
    // Slightly below fiber / sodium so paired highlights favor one mechanism + the plan.
    'blood sugar': 80,
    'blood glucose': 80,
    'insulin resistance': 93,
    'insulin': 92,

    // Conditions
    'diabetes': 90,
    'pre-diabetes': 90,
    'hypertension': 89,
    'blood pressure': 88,
    'fasting blood sugar': 88,
    'obesity': 88,

    // Actionable diet concepts (UX-critical)
    'portion size': 87,
    'fiber': 86,
    'sodium': 86,
    'added sugar': 85,
    'refined carbs': 84,
    'complex carbs': 84,
    'simple carbs': 83,
    'low gi': 78,
    'whole grains': 75,

    // Food quality
    'nutrient-dense': 82,
    'whole foods': 80,
    'processed food': 78,
    'empty calories': 76,
    // Core Diabetes Plate term — appears in nearly every meal response.
    'non-starchy vegetables': 65,

    // Lean protein: above generic "protein" so phrase wins when both could match.
    'lean protein': 52,

    // Risk / outcomes
    'heart disease': 72,
    'stroke': 70,
    'cholesterol': 70,
    'cholesterol levels': 68,
    'hdl': 67,
    'ldl': 67,
    'potassium': 66,
    'cortisol': 65,
    'blood pressure reading': 63,
    'omega-3': 62,
    'meal timing': 60,
    'brisk walking': 58,
    'sleep apnea': 57,
    'insomnia': 55,
    'plant-based protein': 54,
    'legumes': 53,
    'oats': 50,
    'brown rice': 49,
    'whole wheat': 48,
    'unsalted nuts': 47,
    'sleep schedule': 46,

    // Planning / general
    'body mass index': 64,
    'balanced diet': 62,
    'calorie deficit': 60,
    'calorie intake': 58,

    // Low-priority
    'protein': 45,
    'carbohydrates': 43,
    'healthy fats': 41,
    'satiety': 39,
    'hydration': 37,
    'metabolism': 35,
  };

  static const Map<String, String> definitions = {
    'calories':
        'Calories are the energy your body gets from foods like rice and bread.',
    'nutrients':
        'Nutrients, including vitamins and protein, are parts of food that help your body function.',
    'nutrient-dense':
        'Nutrient-dense foods give your body a lot of vitamins, minerals and fiber for the number of calories they contain. Examples include spinach, eggs and beans.',
    'protein':
        'Protein helps build and repair muscles and is found in foods like chicken, eggs and beans.',
    'carbohydrates':
        'Carbohydrates, such as rice, bread and pasta, are the body\'s main source of energy.',
    'fat':
        'Fats provide energy and support body functions and are found in foods like nuts, oil and butter.',
    'fiber':
        'Fiber is found in fruits, vegetables, beans and whole grains. It slows digestion, which helps keep blood sugar steady. It also helps lower cholesterol and supports a healthy weight.',
    'sugar':
        'Sugar is a simple carbohydrate that provides quick energy and is found in foods like fruits and sweets.',
    'added sugar':
        'Added sugar is sugar put into foods during processing, like in soda, juice and packaged snacks. It raises blood sugar quickly. Most adults should limit it to 25–36 grams per day.',
    'sodium':
        'Sodium is a mineral found in salt and many packaged foods. Too much sodium can raise blood pressure. Most adults should have less than 2,300 mg per day — about one teaspoon of salt.',
    'vitamins':
        'Vitamins are nutrients needed in small amounts and are found in foods like fruits and vegetables.',
    'minerals':
        'Minerals support body functions like bone health and are found in foods like milk and leafy greens.',
    'portion':
        'A portion is how much food you choose to put on your plate. It may be more or less than the recommended serving size.',
    'serving size':
        'A serving size is the standard amount listed on a food label. Many packages contain 2 or more servings, so check before eating the whole package.',
    'balanced diet':
        'A balanced diet includes a variety of foods like grains, vegetables and proteins.',
    'whole grains':
        'Whole grains like brown rice, oats and whole wheat bread contain all parts of the grain. They have more fiber than white bread or white rice, which helps keep blood sugar steady.',
    'refined grains':
        'Refined grains, such as white bread, are processed and have less fiber.',
    'processed food':
        'Processed foods, like chips and packaged snacks, are altered from their natural form.',
    'lean protein':
        'Lean proteins, like chicken breast and fish, provide protein with less fat.',
    'red meat':
        'Red meat, such as beef and lamb, comes from animals and can be higher in fat.',
    'low-fat': 'Low-fat foods, such as low-fat milk, have reduced fat content.',
    'fat-free': 'Fat-free foods, like fat-free yogurt, contain little to no fat.',
    'plant-based food':
        'Plant-based foods come from plants, such as beans, vegetables and fruits.',
    'digestion':
        'Digestion is the process of breaking down food into nutrients your body can use.',
    'metabolism': 'Metabolism is how your body uses energy from food to function.',
    'blood sugar':
        'Blood sugar is the amount of glucose in your blood. Keeping it steady helps prevent diabetes problems. A normal level before eating is below 100 mg/dL.',
    'blood glucose':
        'Blood glucose is another name for blood sugar.',
    'cholesterol':
        'Cholesterol is a fat-like substance in your blood. HDL is the good kind that protects your heart. LDL is the bad kind that can clog your arteries. Eating fish, nuts and fiber helps keep cholesterol healthy.',
    'insulin':
        'Insulin is a hormone that helps move glucose from the blood into cells for energy.',
    'insulin resistance':
        'Insulin resistance is when your body does not use insulin well. This makes blood sugar stay too high. Healthy eating and regular movement can help improve it.',
    'glycemic index':
        'The glycemic index (GI) shows how fast a food raises blood sugar. Foods like beans and oats raise it slowly. White bread raises it quickly. Lower is better.',
    'glycemic load':
        'Glycemic load shows how much a food raises your blood sugar based on how much you actually eat. A small portion of a sugary food may still have a low glycemic load.',
    'complex carbs':
        'Complex carbohydrates, such as oats and whole grains, are digested slowly and provide steady energy.',
    'simple carbs':
        'Simple carbohydrates, like sugar, are digested quickly and raise blood sugar fast.',
    'refined carbs':
        'Refined carbs are processed carbohydrates like white bread that digest quickly.',
    'whole foods':
        'Whole foods are natural foods that are not heavily processed, like fruits, vegetables and grains.',
    'empty calories':
        'Empty calories are calories with little nutrition, such as from sugary drinks and snacks.',
    'non-starchy vegetables':
        'Non-starchy vegetables are low-carb vegetables like spinach, broccoli and cucumbers.',
    'healthy fats':
        'Healthy fats, such as those in olive oil and nuts, support heart health.',
    'saturated fat':
        'Saturated fats, found in butter and fatty meats, can raise cholesterol levels.',
    'unsaturated fat':
        'Unsaturated fats, found in fish and nuts, are better for heart health.',
    'appetite':
        'Appetite is your desire to eat, even if you are not very hungry.',
    'cravings':
        'Cravings are strong desires for specific foods, such as chocolate or chips.',
    'overeating': 'Overeating means eating more food than your body needs.',
    'portion control':
        'Portion control means managing how much food you eat at each meal.',
    'portion size':
        'Portion size is how much food you choose to eat at one time.',
    'satiety':
        'Satiety is the feeling of being full after eating.',
    'diabetes plate':
        'The Diabetes Plate is a simple way to plan meals. Fill half your plate with vegetables, one quarter with protein and one quarter with carbs to help keep blood sugar steady.',
    'myplate':
        'MyPlate is a guide for balanced meals. Fill half your plate with fruits and vegetables and the other half with grains and protein, with some dairy on the side.',
    'hydration':
        'Hydration means having enough water in your body by drinking fluids regularly.',
    'dehydration':
        'Dehydration happens when your body does not have enough water, causing thirst and tiredness.',
    'fluid intake':
        'Fluid intake is the total amount of liquids you drink, including water and milk.',
    'sugary drinks':
        'Sugary drinks, like soda, contain added sugars and extra calories.',
    'energy drinks':
        'Energy drinks, such as Red Bull, contain caffeine and sugar to boost energy.',
    'caffeine':
        'Caffeine is a stimulant found in drinks like coffee that increases alertness but can affect sleep if taken late.',
    'alcohol':
        'Alcohol is a beverage that can affect the brain and body and may lead to dehydration when consumed in excess.',
    'exercise':
        'Exercise is planned physical activity, such as working out at the gym.',
    'physical activity':
        'Physical activity includes any movement, such as walking or doing household work.',
    'brisk walking':
        'Brisk walking means walking fast enough to raise your heart rate and feel slightly out of breath, but still able to talk. 30 minutes most days is one of the best things you can do for blood sugar and blood pressure.',
    'strength training':
        'Strength training is exercise that uses resistance to build and maintain muscle mass.',
    'cardio':
        'Cardio exercises, like running or cycling, improve heart health.',
    'walking': 'Walking is a simple form of physical activity done daily.',
    'running': 'Running is a faster activity that improves fitness and endurance.',
    'cycling': 'Cycling is riding a bicycle for exercise or transport.',
    'stretching': 'Stretching improves flexibility and reduces muscle tightness.',
    'muscle': 'Muscles are body tissues that help you move.',
    'fitness':
        'Fitness is your overall physical health and ability to stay active.',
    'active lifestyle':
        'An active lifestyle includes regular movement, such as taking stairs or walking often.',
    'sedentary':
        'A sedentary lifestyle means sitting or resting most of the day with little movement. This can increase the risk of diabetes, high blood pressure and weight gain.',
    'blood pressure':
        'Blood pressure is the force of blood moving through your arteries, such as a reading of 120/80.',
    'hypertension':
        'Hypertension is high blood pressure. Stage 1 is 130/80 or higher; Stage 2 is 140/90 or higher. Reducing sodium and staying active help manage it.',
    'hypertension stage 1':
        'Stage 1 hypertension means blood pressure is around 130/80 or higher.',
    'body mass index':
        'Body mass index (BMI) is a number based on your height and weight. It helps show if your weight is in a healthy range.',
    'diabetes':
        'Diabetes is a condition where blood sugar levels are too high, often requiring careful management of carbohydrate intake.',
    'pre-diabetes':
        'Pre-diabetes is when blood sugar is higher than normal but not yet at diabetes levels. The good news is that lifestyle changes like healthy eating and regular movement can often reverse it.',
    'obesity':
        'Obesity is a health condition where body weight is higher than what is considered healthy for a person\'s height. It can be managed with support from healthy eating and physical activity.',
    'heart disease':
        'Heart disease includes conditions that affect the heart and blood vessels, such as blocked arteries.',
    'stroke':
        'Stroke occurs when blood flow to the brain is blocked or reduced, leading to brain damage.',
    'cholesterol levels':
        'Cholesterol levels refer to the amount of cholesterol measured in your blood.',
    'hdl':
        'HDL is the "good" cholesterol. Higher HDL levels help protect your heart. Foods like fish, nuts and olive oil help raise HDL.',
    'ldl':
        'LDL is the "bad" cholesterol. Too much LDL can build up in your arteries and raise your risk of heart disease. Eating less processed food and saturated fat helps lower LDL.',
    'immune system':
        'The immune system protects your body from infections and illness.',
    'hormones':
        'Hormones are chemicals, such as insulin, that control body functions.',
    'sleep quality':
        'Sleep quality refers to how well you sleep, including how deeply and continuously you rest.',
    'sleep schedule':
        'A sleep schedule means going to bed and waking up at the same time every day. A regular sleep schedule helps your body know when to rest, which improves sleep quality and blood sugar control.',
    'stress':
        'Stress is the body\'s physical and mental response to challenges or demands.',
    'mental health':
        'Mental health refers to your emotional and psychological well-being.',
    'energy levels':
        'Energy levels describe how active or tired you feel during the day.',
    'insomnia': 'Insomnia is difficulty falling asleep or staying asleep.',
    'sleep apnea':
        'Sleep apnea is when your breathing stops and starts while you sleep. It can cause poor sleep, tiredness and higher blood sugar and blood pressure.',
    'weight management':
        'Weight management involves maintaining a healthy body weight through balanced eating and physical activity.',
    'body weight':
        'Body weight is the total weight of your body measured in units like kilograms.',
    'body fat':
        'Body fat is the fat stored in your body, such as around the abdomen.',
    'calorie intake':
        'Calorie intake is the total number of calories you consume daily.',
    'calorie deficit':
        'A calorie deficit means you eat fewer calories than your body burns. Over time, this leads to weight loss.',
    'healthy habits':
        'Healthy habits are behaviors like eating well and staying active.',
    'dash diet':
        'The DASH diet is a low-sodium eating plan. It focuses on fruits, vegetables, whole grains and lean protein to help lower blood pressure.',
    'low-sodium diet':
        'A low-sodium diet limits salt intake to help control blood pressure.',
    'diet plan':
        'A diet plan is a structured way of eating based on health goals.',
    'meal planning':
        'Meal planning means deciding meals in advance to maintain healthy eating.',
    'balanced plate':
        'A balanced plate includes proper portions of vegetables, protein and carbohydrates.',
    'potassium':
        'Potassium is a mineral that helps regulate fluid balance and supports healthy blood pressure and is found in foods like bananas.',
    'magnesium':
        'Magnesium supports muscle and nerve function and is found in foods like nuts and leafy greens.',
    'calcium':
        'Calcium is a mineral that is essential for strong bones, teeth and muscle function and is found in milk.',
    'iron':
        'Iron is a mineral that helps carry oxygen in the blood through red blood cells and is found in foods like spinach and meat.',
    'fiber intake':
        'Fiber intake is the amount of fiber you consume daily from foods like fruits and whole grains.',
    'protein intake':
        'Protein intake is the amount of protein you consume from foods like eggs, chicken and beans.',
    'carbohydrate intake':
        'Carbohydrate intake is the amount of carbohydrates you eat from foods like rice and bread.',
    'physical activity level':
        'Physical activity level refers to how active you are during the day.',
    'sedentary time':
        'Sedentary time is the amount of time you spend sitting or inactive.',
    'consistency':
        'Consistency means doing healthy behaviors regularly over time.',
    'lifestyle change':
        'A lifestyle change is improving daily habits to support better health.',
    'risk factors':
        'Risk factors are habits or health conditions that make it more likely you will get a disease. Examples include smoking, poor eating and not being active.',
    'prevention':
        'Prevention means taking steps to stop a disease before it starts. Eating well, staying active and getting enough sleep all help prevent chronic diseases.',
    'chronic disease':
        'A chronic disease is a long-term health condition that does not go away. Examples include diabetes and high blood pressure. Healthy habits help manage it.',

    'fasting blood sugar':
        'Fasting blood sugar is your blood sugar level after not eating for 8 hours or more. Below 100 is normal. 100 to 125 means prediabetes. 126 or above may mean diabetes.',
    'hba1c':
        'HbA1c (A1c) shows your average blood sugar over the past 2 to 3 months. Below 5.7% is normal. 5.7 to 6.4% is prediabetes. 6.5% or above is diabetes.',
    'brown rice':
        'Brown rice is a whole grain that has more fiber than white rice. It digests more slowly, which helps keep blood sugar steady.',
    'whole wheat':
        'Whole wheat products like whole wheat bread use the entire wheat grain. They have more fiber than white bread and help keep blood sugar steadier.',
    'legumes':
        'Legumes are foods like beans, lentils and chickpeas. They are high in fiber and protein, which helps keep blood sugar steady and supports heart health.',
    'omega-3':
        'Omega-3s are healthy fats found in fish like salmon and sardines. They help protect your heart and reduce swelling inside the body.',
    'blood pressure reading':
        'A blood pressure reading has two numbers, like 120/80. The top is pressure when your heart beats; the bottom is when it rests. Below 120/80 is normal.',
    'cortisol':
        'Cortisol is a stress hormone. When you feel stressed or do not sleep well, cortisol goes up. This can raise your blood sugar and blood pressure.',
    'plant-based protein':
        'Plant-based protein comes from foods like beans, lentils, tofu and nuts. These provide protein without the saturated fat found in red meat.',
    'low gi':
        'Low GI means a food has a glycemic index of 55 or below. These foods raise blood sugar slowly. Examples include beans, oats and most vegetables.',
    'oats':
        'Oats are a whole grain that are high in fiber. They digest slowly and help keep blood sugar steady. They also support heart health by lowering cholesterol.',
    'unsalted nuts':
        'Unsalted nuts are nuts with no added salt. They are a healthy snack for blood sugar and blood pressure because they have healthy fats and protein without extra sodium.',
    'meal timing':
        'Meal timing means eating at the same times each day. Eating regularly helps keep your blood sugar steady and prevents it from going too high or too low.',
  };

  static const Map<String, String> aliases = {
    'carbs': 'carbohydrates',
    'bp': 'blood pressure',
    'htn': 'hypertension',
    'dm': 'diabetes',
    'diabetesplate': 'diabetes plate',
    'my plate': 'myplate',
    'sugar levels': 'blood sugar',
    'bmi': 'body mass index',
    'prediabetes': 'pre-diabetes',
    'a1c': 'hba1c',
    'low sodium': 'sodium',
    'low-sodium': 'sodium',
    'beans': 'legumes',
    'lentils': 'legumes',
    'gi': 'glycemic index',
    'fasting glucose': 'fasting blood sugar',
    'chickpeas': 'legumes',
    'salmon': 'omega-3',
    'sardines': 'omega-3',
    'oatmeal': 'oats',
  };

  static String normalizeTerm(String term) => term.trim().toLowerCase();

  /// Readable sheet title (title case words; preserves hyphen segments like “pre-diabetes”).
  static String displayTitleForCanonical(String canonical) {
    String titleCaseWord(String word) {
      if (word.isEmpty) return word;
      final first = word[0].toUpperCase();
      final rest =
          word.length > 1 ? word.substring(1).toLowerCase() : '';
      return '$first$rest';
    }

    return canonical
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((word) => word.split('-').map(titleCaseWord).join('-'))
        .join(' ');
  }

  /// Extra score when [conditionHints] is non-empty (e.g. profile conditions).
  /// Wire real hints from the app when user context is available.
  static int conditionPriorityBoost(
    String canonical, [
    Set<String>? conditionHints,
  ]) {
    final hints = conditionHints;
    if (hints == null || hints.isEmpty) return 0;

    final blob = hints.map((e) => e.toLowerCase()).join(' ');
    final c = canonical.toLowerCase();
    var boost = 0;

    if (blob.contains('diabet') ||
        blob.contains('prediabet') ||
        blob.contains('glucose')) {
      const keys = <String>{
        'glycemic index',
        'glycemic load',
        'blood sugar',
        'blood glucose',
        'insulin',
        'insulin resistance',
        'carbohydrates',
        'complex carbs',
        'simple carbs',
        'fiber',
        'diabetes',
        'pre-diabetes',
      };
      if (keys.contains(c)) boost += 22;
    }

    if (blob.contains('hypertension') ||
        blob.contains('blood pressure') ||
        blob.contains('heart')) {
      const keys = <String>{
        'blood pressure',
        'hypertension',
        'hypertension stage 1',
        'sodium',
        'salt',
        'potassium',
        'dash diet',
        'low-sodium diet',
      };
      if (keys.contains(c)) boost += 22;
    }

    if (blob.contains('obes') ||
        blob.contains('weight') ||
        blob.contains('overweight')) {
      const keys = <String>{
        'fiber',
        'portion size',
        'portion',
        'calorie deficit',
        'calorie intake',
        'weight management',
        'body mass index',
        'obesity',
        'satiety',
      };
      if (keys.contains(c)) boost += 22;
    }

    return boost;
  }

  /// Group id for [semanticPrimeGroup] limits, if any.
  static String? semanticGroupForCanonical(String canonical) =>
      semanticPrimeGroup[canonical.trim().toLowerCase()];
}
