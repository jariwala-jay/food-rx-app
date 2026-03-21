"""
Food & Nutrition Knowledge Base for MyFoodRx RAG Chatbot.

Sources: CDC, AHA (American Heart Association), ADA (American Diabetes Association),
USDA (MyPlate), NIH (National Heart, Lung, and Blood Institute).

Each document has: title, content, category, source.
"""

KNOWLEDGE_DOCS = [
    # ─── DASH DIET ──────────────────────────────────────────────────────────
    {
        "id": "dash_overview",
        "title": "What Is the DASH Diet?",
        "category": "DASH Diet",
        "source": "NIH / NHLBI",
        "content": (
            "DASH stands for Dietary Approaches to Stop Hypertension. "
            "The DASH diet is a healthy eating plan designed to help lower high blood pressure (hypertension). "
            "It was developed by the National Heart, Lung, and Blood Institute (NHLBI). "
            "The DASH diet focuses on fruits, vegetables, whole grains, lean protein, and low-fat dairy. "
            "It limits foods high in saturated fat, sodium (salt), and added sugar. "
            "Studies show the DASH diet can lower blood pressure in as little as two weeks. "
            "It is recommended by the American Heart Association (AHA) for heart health."
        ),
    },
    {
        "id": "dash_food_groups",
        "title": "DASH Diet: What to Eat",
        "category": "DASH Diet",
        "source": "NIH / NHLBI",
        "content": (
            "On the DASH diet, eat these foods every day: "
            "Grains (6–8 servings): Bread, pasta, rice, cereals — choose whole grain. "
            "Vegetables (4–5 servings): Broccoli, carrots, spinach, sweet potatoes, tomatoes. "
            "Fruits (4–5 servings): Apples, bananas, berries, oranges, grapes. "
            "Low-fat dairy (2–3 servings): Fat-free milk, low-fat yogurt, low-fat cheese. "
            "Lean meats, poultry, fish (6 or fewer servings): Chicken, turkey, fish — remove skin and trim fat. "
            "Nuts, seeds, legumes (4–5 servings per week): Almonds, sunflower seeds, kidney beans, peas. "
            "Fats and oils (2–3 servings): Use olive oil or vegetable oil instead of butter. "
            "Sweets (5 or fewer per week): Small amounts of jam, sorbet, or low-fat cookies."
        ),
    },
    {
        "id": "dash_sodium",
        "title": "DASH Diet: Reducing Salt (Sodium)",
        "category": "DASH Diet",
        "source": "NIH / NHLBI / AHA",
        "content": (
            "Eating less salt (sodium) is very important for lowering blood pressure. "
            "The standard DASH diet limits sodium to 2,300 mg per day — about 1 teaspoon of table salt. "
            "A lower-sodium version limits sodium to 1,500 mg per day for greater blood pressure benefits. "
            "Tips to reduce sodium: Cook from scratch instead of eating processed or packaged foods. "
            "Read food labels — choose products with less than 5% Daily Value of sodium. "
            "Use herbs and spices instead of salt to season food. "
            "Avoid adding salt at the table. "
            "Limit canned soups, frozen dinners, deli meats, and fast food — these are very high in sodium. "
            "Rinse canned beans and vegetables before eating to remove extra sodium."
        ),
    },
    {
        "id": "dash_hypertension",
        "title": "DASH Diet and High Blood Pressure (Hypertension)",
        "category": "DASH Diet",
        "source": "AHA / NIH",
        "content": (
            "High blood pressure (hypertension) means the force of blood pushing against artery walls is too high. "
            "Normal blood pressure is below 120/80 mmHg. "
            "Stage 1 hypertension is 130–139/80–89 mmHg. "
            "The DASH diet is one of the most proven ways to lower blood pressure without medicine. "
            "Eating potassium-rich foods like bananas, potatoes, and spinach helps lower blood pressure. "
            "Getting enough calcium and magnesium also helps — found in dairy, leafy greens, and nuts. "
            "Limiting alcohol to no more than 1 drink per day for women and 2 for men also helps. "
            "Combining the DASH diet with regular exercise can lower blood pressure even more. "
            "Always work with your doctor if you take blood pressure medicine — diet changes should complement, not replace, medical treatment."
        ),
    },

    # ─── MYPLATE ────────────────────────────────────────────────────────────
    {
        "id": "myplate_overview",
        "title": "What Is MyPlate?",
        "category": "MyPlate",
        "source": "USDA",
        "content": (
            "MyPlate is the U.S. government's guide to healthy eating, created by the USDA. "
            "The MyPlate icon shows a dinner plate divided into four sections: "
            "Fruits, Vegetables, Grains, and Protein — with a small circle of Dairy on the side. "
            "Half of every plate should be fruits and vegetables. "
            "A quarter of the plate should be whole grains. "
            "A quarter of the plate should be lean protein. "
            "MyPlate encourages variety, balance, and moderation in eating. "
            "The goal is to help people make healthier food choices at every meal."
        ),
    },
    {
        "id": "myplate_food_groups",
        "title": "MyPlate: The Five Food Groups",
        "category": "MyPlate",
        "source": "USDA",
        "content": (
            "MyPlate has five food groups: "
            "1. Vegetables: Fill half your plate. Eat a variety of colors — dark green (spinach, broccoli), red/orange (carrots, sweet potatoes), beans and peas, starchy vegetables (corn, potatoes). "
            "2. Fruits: Fill half your plate with fruits and vegetables together. Choose whole fruits over juice — fresh, frozen, canned (in water or juice), or dried. "
            "3. Grains: Make at least half your grains whole grains like whole wheat bread, brown rice, oatmeal. Limit refined grains like white bread and white rice. "
            "4. Protein: Choose lean or low-fat protein — chicken, turkey, fish, eggs, beans, peas, nuts, and seeds. Eat seafood at least twice a week. "
            "5. Dairy: Choose fat-free or low-fat milk, yogurt, and cheese. Dairy provides calcium and vitamin D. "
            "Limit added sugars, sodium, and saturated fats."
        ),
    },
    {
        "id": "myplate_portion_sizes",
        "title": "MyPlate: Understanding Serving Sizes",
        "category": "MyPlate",
        "source": "USDA",
        "content": (
            "A serving size is the measured amount of food. "
            "Easy portion guides: "
            "1 cup of pasta or cereal = a baseball. "
            "3 oz of meat or fish (one serving) = a deck of cards. "
            "1 oz of cheese = four dice stacked. "
            "1 tablespoon of peanut butter = a poker chip. "
            "1 cup of fruit or vegetables = your fist. "
            "Half a cup of cooked grains = a rounded handful. "
            "A medium piece of fruit = a tennis ball. "
            "Eating recommended serving sizes helps manage calories, blood sugar, and weight. "
            "Use smaller plates to make portions look bigger and help avoid overeating."
        ),
    },

    # ─── DIABETES PLATE / ADA ───────────────────────────────────────────────
    {
        "id": "diabetes_plate_overview",
        "title": "What Is the Diabetes Plate Method?",
        "category": "Diabetes Plate",
        "source": "ADA (American Diabetes Association)",
        "content": (
            "The Diabetes Plate Method is a simple way to eat healthy meals that help manage blood sugar. "
            "It was created by the American Diabetes Association (ADA). "
            "Use a 9-inch dinner plate and divide it like this: "
            "Half the plate (1/2) = Non-starchy vegetables. "
            "One quarter of the plate (1/4) = Lean protein. "
            "One quarter of the plate (1/4) = Carbohydrates (grains, starchy vegetables, or fruit). "
            "Add a small serving of healthy fat (like avocado or olive oil) on the side. "
            "Drink water or a low-calorie beverage with your meal. "
            "This method helps control blood sugar without counting carbs or measuring food."
        ),
    },
    {
        "id": "diabetes_nonstarchy_veggies",
        "title": "Diabetes Diet: Non-Starchy Vegetables",
        "category": "Diabetes Plate",
        "source": "ADA",
        "content": (
            "Non-starchy vegetables are low in carbohydrates and calories. They fill half the plate on the Diabetes Plate. "
            "Examples of non-starchy vegetables: Spinach, kale, lettuce, collard greens, broccoli, cauliflower, "
            "cabbage, green beans, asparagus, cucumbers, celery, tomatoes, peppers, mushrooms, onions, eggplant, zucchini. "
            "These vegetables are high in fiber, vitamins, and minerals. "
            "Fiber slows digestion and helps prevent blood sugar spikes. "
            "Eat a variety of colors for the most nutrients. "
            "Cook with little or no added salt, butter, or sauce."
        ),
    },
    {
        "id": "diabetes_carbs",
        "title": "Diabetes Diet: Managing Carbohydrates",
        "category": "Diabetes Plate",
        "source": "ADA / CDC",
        "content": (
            "Carbohydrates (carbs) raise blood sugar. Managing carbs is key for diabetes. "
            "On the Diabetes Plate, carbs fill one quarter (1/4) of the plate. "
            "Good carb choices: Whole grains (brown rice, whole wheat bread, oatmeal), "
            "beans and lentils, sweet potatoes, corn, fruit, and low-fat dairy. "
            "Avoid or limit: White bread, white rice, sugary drinks (soda, juice), candy, pastries, chips. "
            "Eating carbs with protein and fiber slows digestion and lowers blood sugar spikes. "
            "Spread carbs evenly through the day — do not eat all carbs at one meal. "
            "A registered dietitian can help you find the right amount of carbs for your needs."
        ),
    },
    {
        "id": "diabetes_glycemic_index",
        "title": "Glycemic Index and Diabetes",
        "category": "Diabetes Plate",
        "source": "ADA / CDC",
        "content": (
            "The glycemic index (GI) measures how fast a food raises blood sugar. "
            "Low GI foods (55 or less) raise blood sugar slowly. These are better choices for diabetes: "
            "Oatmeal, brown rice, whole grain bread, apples, oranges, beans, lentils, non-starchy vegetables. "
            "High GI foods (70 or more) raise blood sugar quickly: White bread, white rice, watermelon, corn flakes, instant oatmeal, sugary drinks. "
            "Medium GI foods (56–69): Basmati rice, honey, whole wheat bread. "
            "Eating low-GI foods helps keep blood sugar stable. "
            "Combine high-GI foods with protein or fat to slow the rise in blood sugar."
        ),
    },
    {
        "id": "prediabetes_prevention",
        "title": "Prediabetes: Preventing Type 2 Diabetes Through Diet",
        "category": "Diabetes Plate",
        "source": "CDC",
        "content": (
            "Prediabetes means your blood sugar is higher than normal but not high enough for type 2 diabetes. "
            "About 96 million American adults have prediabetes — and most do not know it. "
            "Without lifestyle changes, prediabetes can become type 2 diabetes within 5 years. "
            "Diet changes that help: Eat more vegetables, fruits, and whole grains. "
            "Cut back on sugary drinks, sweets, and processed foods. "
            "Choose smaller portion sizes. Lose 5–7% of body weight if you are overweight. "
            "Physical activity also helps — aim for 150 minutes of moderate activity per week (like brisk walking). "
            "These changes can reduce your risk of type 2 diabetes by 58%."
        ),
    },

    # ─── HYPERTENSION / HEART HEALTH ────────────────────────────────────────
    {
        "id": "hypertension_overview",
        "title": "Understanding High Blood Pressure (Hypertension)",
        "category": "Hypertension",
        "source": "AHA / CDC",
        "content": (
            "High blood pressure (hypertension) is sometimes called the 'silent killer' because it often has no symptoms. "
            "It means the heart is working too hard to pump blood. "
            "Normal: Less than 120/80. Elevated: 120–129/less than 80. "
            "Stage 1 Hypertension: 130–139/80–89. Stage 2 Hypertension: 140 or higher/90 or higher. "
            "Long-term high blood pressure can lead to heart attack, stroke, and kidney disease. "
            "Diet is one of the most powerful ways to control blood pressure. "
            "Key diet steps: Reduce sodium (salt), eat potassium-rich foods, limit alcohol, and follow the DASH diet. "
            "Other lifestyle changes: Exercise regularly, maintain a healthy weight, manage stress, quit smoking."
        ),
    },
    {
        "id": "heart_healthy_fats",
        "title": "Heart-Healthy Fats: What to Choose",
        "category": "Hypertension",
        "source": "AHA",
        "content": (
            "Not all fats are bad. Choosing the right fats helps protect your heart. "
            "Healthy fats (eat more): Unsaturated fats found in olive oil, avocado, nuts, seeds, and fatty fish (salmon, tuna, mackerel). "
            "These fats lower bad (LDL) cholesterol. "
            "Fats to limit: Saturated fats found in butter, full-fat dairy, fatty meats, and coconut oil. "
            "Fats to avoid: Trans fats found in some packaged snacks and fried fast foods. Trans fats raise bad cholesterol and lower good cholesterol. "
            "The AHA recommends replacing saturated fats with unsaturated fats. "
            "Eating fish twice a week provides heart-healthy omega-3 fatty acids."
        ),
    },
    {
        "id": "potassium_foods",
        "title": "Potassium-Rich Foods for Blood Pressure",
        "category": "Hypertension",
        "source": "AHA / NIH",
        "content": (
            "Potassium helps lower blood pressure by balancing the effects of sodium. "
            "Most people should aim for 2,600–3,400 mg of potassium per day. "
            "High-potassium foods: Bananas (422 mg), sweet potatoes (694 mg), spinach (839 mg per cup cooked), "
            "white beans (829 mg), avocado (708 mg), salmon (534 mg), orange juice (496 mg), "
            "plain yogurt (531 mg), lentils (731 mg). "
            "If you have kidney disease, talk to your doctor before eating more potassium — sometimes potassium needs to be limited. "
            "Eating plenty of fruits and vegetables naturally gives you enough potassium."
        ),
    },

    # ─── OBESITY / WEIGHT MANAGEMENT ────────────────────────────────────────
    {
        "id": "obesity_diet",
        "title": "Healthy Eating for Weight Management and Obesity",
        "category": "Weight Management",
        "source": "CDC / NIH",
        "content": (
            "Obesity means having too much body fat. It raises the risk of type 2 diabetes, heart disease, high blood pressure, and other conditions. "
            "Losing even a small amount of weight — 5 to 10% of body weight — can improve health. "
            "Tips for healthy weight loss through diet: "
            "Eat more fruits, vegetables, and whole grains — they are low in calories and filling. "
            "Choose lean proteins: Chicken, fish, beans, eggs. "
            "Cut back on sugary drinks, candy, pastries, and fried foods. "
            "Watch portion sizes — use smaller plates and bowls. "
            "Eat slowly and stop when you feel full. "
            "Avoid skipping meals — skipping often leads to overeating later. "
            "Cook at home more often — restaurant meals are often high in calories, fat, and sodium. "
            "Drink water before meals to help feel fuller."
        ),
    },
    {
        "id": "calories_basics",
        "title": "Understanding Calories and Energy Balance",
        "category": "Weight Management",
        "source": "CDC / NIH",
        "content": (
            "A calorie is a unit of energy found in food. Your body needs calories to work and stay alive. "
            "Weight gain happens when you eat more calories than your body uses. "
            "Weight loss happens when you use more calories than you eat. "
            "Average calorie needs: 1,600–2,000 per day for women; 2,000–2,500 for men (varies with age and activity). "
            "To lose about 1 pound per week, eat 500 fewer calories per day than your body needs. "
            "Do not go below 1,200 calories per day for women or 1,500 for men without medical supervision. "
            "High-calorie foods to eat less of: Fried foods, chips, cookies, full-fat dairy, sugary drinks, white bread. "
            "Low-calorie, filling foods: Vegetables, fruits, broth-based soups, legumes, lean proteins."
        ),
    },
    {
        "id": "fiber_benefits",
        "title": "Dietary Fiber: Benefits and Sources",
        "category": "Weight Management",
        "source": "CDC / ADA",
        "content": (
            "Dietary fiber is the part of plant foods your body cannot digest. "
            "Fiber has many health benefits: Helps you feel full longer, lowers blood sugar, reduces cholesterol, and helps with bowel regularity. "
            "Women should aim for 25 grams of fiber per day; men 38 grams per day. "
            "High-fiber foods: Beans and lentils (15g per cup), avocado (10g), whole wheat (6g per cup), oatmeal (4g per serving), "
            "broccoli (5g per cup), berries (4–8g per cup), pears (5.5g), almonds (3.5g per oz), quinoa (5g per cup). "
            "Tips: Add beans to soups and salads. Eat whole fruit instead of juice. Choose whole grain bread and pasta. "
            "Increase fiber slowly and drink plenty of water to avoid stomach discomfort."
        ),
    },

    # ─── FOOD ALLERGIES / INTOLERANCES ─────────────────────────────────────
    {
        "id": "food_allergies_overview",
        "title": "Common Food Allergies",
        "category": "Food Allergies",
        "source": "FDA / CDC",
        "content": (
            "A food allergy is when the body's immune system reacts to a food as if it were harmful. "
            "The 9 major food allergens in the U.S. are: Milk, Eggs, Fish, Shellfish, Tree nuts, Peanuts, Wheat, Soybeans, and Sesame. "
            "Symptoms can include: Hives, rash, stomach pain, vomiting, swelling, trouble breathing. "
            "Severe reactions (anaphylaxis) require emergency medical care. "
            "The only treatment is to avoid the allergen completely. "
            "Always read food labels carefully. Look for 'Contains:' statements. "
            "Tell restaurant staff about your allergies before ordering. "
            "Food allergies are different from food intolerances — intolerances cause digestive discomfort but are not life-threatening."
        ),
    },
    {
        "id": "lactose_intolerance",
        "title": "Lactose Intolerance: Eating Dairy-Free or Low-Lactose",
        "category": "Food Allergies",
        "source": "NIH / CDC",
        "content": (
            "Lactose intolerance means the body cannot fully digest lactose — the natural sugar in milk. "
            "Symptoms include: Stomach pain, bloating, gas, and diarrhea after eating dairy. "
            "Not all dairy products cause the same symptoms. "
            "Lower-lactose dairy options: Hard cheeses (cheddar, Swiss), yogurt (especially Greek yogurt), and butter contain little lactose. "
            "Lactose-free milk and dairy products are widely available. "
            "Calcium alternatives: Fortified plant milks (almond, oat, soy), canned salmon with bones, tofu, broccoli, kale, and fortified orange juice. "
            "Taking a lactase enzyme supplement before eating dairy can help some people digest it."
        ),
    },
    {
        "id": "gluten_sensitivity",
        "title": "Gluten Sensitivity and Celiac Disease",
        "category": "Food Allergies",
        "source": "NIH / CDC",
        "content": (
            "Gluten is a protein found in wheat, barley, and rye. "
            "Celiac disease is an autoimmune condition where eating gluten damages the small intestine. "
            "Non-celiac gluten sensitivity causes similar symptoms without intestinal damage. "
            "Symptoms: Stomach pain, bloating, diarrhea, fatigue, brain fog. "
            "Treatment: Eat a strictly gluten-free diet. "
            "Gluten-free grains: Rice, corn, oats (labeled gluten-free), quinoa, buckwheat, millet, and potatoes. "
            "Watch for hidden gluten in: Soy sauce, soups, salad dressings, processed meats, beer, and some medicines. "
            "Read food labels carefully — look for 'gluten-free' certification."
        ),
    },

    # ─── GENERAL NUTRITION ──────────────────────────────────────────────────
    {
        "id": "hydration",
        "title": "Staying Hydrated: How Much Water to Drink",
        "category": "General Nutrition",
        "source": "CDC / NIH",
        "content": (
            "Water makes up about 60% of your body. Staying hydrated is important for health. "
            "General guidelines: About 8 cups (64 oz) of water per day — but needs vary by person and activity level. "
            "Men need about 13 cups (3.7 liters) of total water per day; women need about 9 cups (2.7 liters). "
            "Signs of dehydration: Dark yellow urine, dry mouth, headache, feeling tired, or feeling dizzy. "
            "Good sources of hydration: Water is best. Also herbal tea, low-fat milk, fruits (watermelon, oranges), and vegetables (cucumber, celery). "
            "Avoid or limit: Sugary sodas, energy drinks, sweetened juices — these add calories without nutrition. "
            "Drink water before, during, and after exercise. Drink more in hot weather."
        ),
    },
    {
        "id": "healthy_eating_tips",
        "title": "General Healthy Eating Tips",
        "category": "General Nutrition",
        "source": "CDC / AHA / USDA",
        "content": (
            "Simple tips for eating healthier every day: "
            "Eat a rainbow of fruits and vegetables — different colors mean different nutrients. "
            "Choose whole grains over refined grains (whole wheat bread over white bread). "
            "Eat lean proteins at every meal — beans, fish, chicken, eggs, or tofu. "
            "Limit sodium: Choose low-sodium canned goods and read labels. "
            "Reduce added sugar: Avoid sugary drinks, candy, and pastries. "
            "Cook at home — you control the ingredients and portions. "
            "Plan meals ahead of time to avoid unhealthy last-minute choices. "
            "Eat regular meals — do not skip breakfast. "
            "Practice mindful eating: Eat slowly, without distractions, and stop when satisfied. "
            "A registered dietitian can create a personalized eating plan for you."
        ),
    },
    {
        "id": "reading_nutrition_labels",
        "title": "How to Read a Nutrition Facts Label",
        "category": "General Nutrition",
        "source": "FDA",
        "content": (
            "The Nutrition Facts label is found on most packaged food in the U.S. "
            "Key things to look at: "
            "Serving size: All the numbers on the label are for this amount. "
            "Calories: How much energy is in one serving. "
            "% Daily Value (%DV): Shows if a nutrient is low (5% or less) or high (20% or more). "
            "Nutrients to limit: Saturated fat, trans fat, sodium, and added sugars. "
            "Nutrients to get enough of: Fiber, vitamin D, calcium, iron, potassium. "
            "Ingredients list: Items are listed from most to least by weight. Avoid products with sugar, refined grains, or hydrogenated oils near the top. "
            "Look for 'low sodium' (140 mg or less), 'low fat' (3g or less), or 'high fiber' (5g or more)."
        ),
    },
    {
        "id": "pantry_staples",
        "title": "Healthy Pantry Staples to Always Have at Home",
        "category": "Pantry & Meal Prep",
        "source": "USDA / CDC",
        "content": (
            "Stocking a healthy pantry makes it easier to cook nutritious meals. "
            "Grains: Brown rice, whole wheat pasta, oats, quinoa, whole grain bread. "
            "Proteins: Canned beans (black beans, chickpeas, kidney beans), canned tuna or salmon, lentils, eggs. "
            "Canned/jarred: Diced tomatoes (no-salt-added), canned vegetables, low-sodium broth. "
            "Frozen: Frozen vegetables (peas, corn, broccoli, spinach), frozen fruit, frozen fish or chicken. "
            "Oils and condiments: Olive oil, vinegar, low-sodium soy sauce, herbs and spices. "
            "Dairy: Low-fat milk or fortified plant milk, plain low-fat yogurt, low-fat cheese. "
            "Snacks: Nuts and seeds, whole grain crackers, fresh or dried fruit. "
            "These items have a long shelf life and allow you to make many healthy meals at home."
        ),
    },
    {
        "id": "meal_planning",
        "title": "Meal Planning for Better Health",
        "category": "Pantry & Meal Prep",
        "source": "USDA / CDC",
        "content": (
            "Planning meals ahead of time helps you eat healthier and save money. "
            "Steps for meal planning: "
            "1. Check what you already have in your pantry, refrigerator, and freezer. "
            "2. Plan 3–5 meals for the week using MyPlate or your diet plan as a guide. "
            "3. Make a grocery list based on what you need. "
            "4. Buy only what is on your list to avoid impulse purchases. "
            "5. Prep ingredients on one day (chop vegetables, cook grains, marinate proteins). "
            "6. Store meals in containers for easy grab-and-go during the week. "
            "Benefits: Less stress, fewer unhealthy choices, less food waste, and savings on food costs. "
            "Use the MyFoodRx app to track your pantry and find recipes that use what you have."
        ),
    },
    {
        "id": "app_features",
        "title": "MyFoodRx App: Features and How to Use It",
        "category": "App Guide",
        "source": "MyFoodRx",
        "content": (
            "MyFoodRx is a personalized food and nutrition app to help you eat healthier. "
            "Key features: "
            "Pantry Tracker: Add the food items you have at home. The app helps you track what is in your pantry and reminds you of expiring items. "
            "Recipe Suggestions: The app recommends recipes based on your pantry items and your diet plan. "
            "Diet Plans: The app shows your personalized diet plan (DASH, MyPlate, or Diabetes Plate). "
            "Education: Read articles and watch videos about healthy eating for your health conditions. "
            "Health Tracking: Log your daily nutrition, hydration, and health goals. "
            "Chatbot: Ask nutrition questions and get personalized answers based on your health profile. "
            "All recommendations in this app are based on evidence-based dietary guidelines, not medical advice. "
            "Talk to your doctor or dietitian for personal medical advice."
        ),
    },
    {
        "id": "sugar_and_sweeteners",
        "title": "Sugar, Added Sugars, and Sweeteners",
        "category": "General Nutrition",
        "source": "AHA / CDC / ADA",
        "content": (
            "Added sugars are sugars added to food during processing or preparation — not naturally occurring in fruit or milk. "
            "The AHA recommends: Women: No more than 25g (6 tsp) of added sugar per day. Men: No more than 36g (9 tsp) per day. "
            "People with diabetes or prediabetes should limit sugar even more. "
            "Common names for added sugar on labels: High-fructose corn syrup, cane sugar, dextrose, fructose, glucose, maltose, molasses, honey, agave. "
            "High-sugar foods to limit: Sodas, juice, energy drinks, candy, cookies, cakes, sweetened yogurt, granola bars. "
            "Natural sweetener alternatives: Fruit, unsweetened applesauce, cinnamon, vanilla extract (no calories). "
            "Artificial sweeteners (like aspartame, stevia) have fewer calories but are best used in moderation. "
            "Liquid sugar (in drinks) is especially harmful because it does not make you feel full."
        ),
    },
    {
        "id": "physical_activity",
        "title": "Physical Activity and Healthy Eating",
        "category": "General Nutrition",
        "source": "CDC / AHA",
        "content": (
            "Diet and physical activity work together for good health. "
            "Adults should aim for at least 150 minutes of moderate activity per week — like brisk walking. "
            "Or 75 minutes of vigorous activity per week — like jogging or swimming. "
            "Also do muscle-strengthening activities 2 days per week. "
            "Benefits of regular activity: Helps maintain healthy weight, lowers blood sugar, lowers blood pressure, improves mood, and strengthens the heart. "
            "You do not have to do all 150 minutes at once — even 10-minute sessions count. "
            "Find activities you enjoy: Walking, dancing, gardening, swimming, biking, yoga. "
            "Eat a small snack before exercise if you feel low on energy — like a banana or a handful of crackers. "
            "Stay hydrated before, during, and after exercise."
        ),
    },
    {
        "id": "recipe_healthy_cooking",
        "title": "Healthy Cooking Methods and Substitutions",
        "category": "Pantry & Meal Prep",
        "source": "USDA / AHA",
        "content": (
            "How you cook food affects how healthy it is. "
            "Best cooking methods: Baking, grilling, steaming, boiling, poaching, stir-frying with a small amount of oil. "
            "Avoid deep-frying — it adds a lot of calories and unhealthy fat. "
            "Healthy substitutions in cooking: "
            "Use olive oil or cooking spray instead of butter. "
            "Use plain Greek yogurt instead of sour cream. "
            "Use applesauce instead of oil in baking (use same amount). "
            "Use mashed banana instead of sugar in baking. "
            "Use herbs, lemon juice, or vinegar instead of salt. "
            "Use low-sodium broth instead of regular broth. "
            "Use whole grain flour for half of the white flour in recipes. "
            "These small changes reduce calories, saturated fat, sodium, and sugar without sacrificing taste."
        ),
    },
]
