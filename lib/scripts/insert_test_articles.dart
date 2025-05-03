import '../services/mongodb_service.dart';

Future<void> insertTestArticles() async {
  final mongoDBService = MongoDBService();
  await mongoDBService.initialize();

  try {
    // First, delete all existing articles
    print('Dropping existing articles...');
    await mongoDBService.educationalContentCollection.drop();
    print('Existing articles dropped successfully');

    final articles = [
      // Hypertension (4)
      {
        'title': 'What Is High Blood Pressure?',
        'category': 'Hypertension',
        'imageUrl':
            'https://images.unsplash.com/photo-1700832082152-0416a3ee5e60',
        'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
        'content':
            'High blood pressure is also called hypertension. It means the blood in your body is pushing too hard against your blood vessels.\n\n'
                'What are the signs?\n'
                '- Most people have no signs. That is why you must check your blood pressure regularly.\n'
                '- Some people may feel:\n'
                '  - Headache\n'
                '  - Dizziness\n'
                '  - Chest pain\n'
                '  - Blurry vision\n\n'
                'What can you do to stay healthy?\n'
                '- Eat less salt\n'
                '- Eat more fruits and vegetables\n'
                '- Move your body – walk, dance, or play\n'
                '- Lose weight if you are overweight\n'
                '- Stop drinking too much alcohol',
      },
      {
        'title': 'Easy Ways to Lower Your Blood Pressure',
        'category': 'Hypertension',
        'imageUrl':
            'https://images.unsplash.com/photo-1605291535356-3ff47e120bc4',
        'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
        'content':
            'Lowering your blood pressure can help your heart and kidneys stay healthy. Small steps can make a big difference.\n\n'
                'Steps to try:\n'
                '- Eat more fruits and vegetables each day\n'
                '- Choose whole grains instead of white bread\n'
                '- Walk 30 minutes most days of the week\n'
                '- Limit salty and processed foods\n'
                '- Talk to your doctor about medicine if needed',
      },
      {
        'title': 'Why Salt Affects Your Heart',
        'category': 'Hypertension',
        'imageUrl':
            'https://images.unsplash.com/photo-1628352127589-39ede70469e7',
        'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
        'content':
            'Salt can make your body hold extra water. This extra water puts more pressure on your heart and blood vessels.\n\n'
                'Why salt matters?\n'
                '- It raises your blood pressure\n'
                '- It makes your heart work harder\n'
                '- Most packaged foods are high in salt\n\n'
                'What you can do?\n'
                '- Use herbs and spices instead of salt\n'
                '- Choose fresh foods over processed\n'
                '- Read food labels for lower-salt options',
      },
      {
        'title': 'Move More to Control Blood Pressure',
        'category': 'Hypertension',
        'imageUrl':
            'https://images.unsplash.com/photo-1707741100133-443bccf78f99',
        'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
        'content':
            'Moving your body helps your heart pump blood better and lowers pressure.\n\n'
                'How much activity?\n'
                '- Aim for 30 minutes each day\n'
                '- You can walk, dance, or bike\n\n'
                'Tips to get started:\n'
                '- Break into 10-minute chunks\n'
                '- Ask a friend or family to join\n'
                '- Choose activities you enjoy',
      },

      // Diabetes (4)
      {
        'title': 'What Is Diabetes?',
        'category': 'Diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1685485276224-d78ce78f3b95',
        'medicalConditionTags': [
          'Diabetes',
          'Lower blood glucose (Sugar)',
          'Avoid diabetes'
        ],
        'content':
            'Diabetes means the sugar in your blood is too high. Over time, high sugar can hurt your eyes, heart, and kidneys.\n\n'
                'How do you know?\n'
                '- You may feel very thirsty\n'
                '- You might urinate more often\n'
                '- You may feel tired or have blurry vision\n'
                '- Some people have no clear signs\n\n'
                'What can you do?\n'
                '- Check your blood sugar as your doctor tells you\n'
                '- Eat regular meals with protein and vegetables\n'
                '- Move your body for at least 30 minutes most days\n'
                '- Take medicine or insulin if prescribed\n'
                '- See your doctor for regular check-ups',
      },
      {
        'title': 'Know Your Blood Sugar Numbers',
        'category': 'Diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1685660478073-ab6b01a529cf',
        'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
        'content':
            'Knowing your blood sugar numbers helps you stay in control. Your doctor will tell you your target ranges.\n\n'
                'Targets to remember:\n'
                '- Before meals: 80–130 mg/dL\n'
                '- One to two hours after meals: below 180 mg/dL\n\n'
                'Tips:\n'
                '- Keep a log of your readings\n'
                '- Share your numbers with your care team\n'
                '- Ask what your personal goals are',
      },
      {
        'title': 'Healthy Snacks for Diabetes',
        'category': 'Diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1725883691833-97103ecd582a',
        'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
        'content':
            'Choosing the right snacks can keep your blood sugar steady and prevent big rises.\n\n'
                'Good snack ideas:\n'
                '- A small apple with peanut butter\n'
                '- Greek yogurt with berries\n'
                '- Veggie sticks with hummus\n'
                '- A handful of nuts\n\n'
                'Tip:\n'
                '- Check your blood sugar after snacks to see how you respond',
      },
      {
        'title': 'Stay Active for Diabetes',
        'category': 'Diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1518611012118-696072aa579a',
        'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
        'content':
            'Moving your body helps your cells use sugar and can lower your blood sugar.\n\n'
                'Activity tips:\n'
                '- Aim for 30 minutes most days\n'
                '- Try walking, swimming, or biking\n'
                '- Use the stairs instead of elevators\n\n'
                'Safety:\n'
                '- Check your blood sugar before and after exercise\n'
                '- Wear good shoes to protect your feet',
      },

      // Obesity (4)
      {
        'title': 'What Is Obesity?',
        'category': 'Obesity',
        'imageUrl':
            'https://images.unsplash.com/photo-1634463278803-f9f71890e67d',
        'medicalConditionTags': ['Obesity', 'Lose weight'],
        'content':
            'Obesity means having too much body fat. It can raise your risk for heart disease, diabetes, and high blood pressure.\n\n'
                'How do you know?\n'
                '- Body Mass Index (BMI) over 30 means obesity\n'
                '- BMI = weight (kg) ÷ height (m)²\n'
                '- You can use a free online BMI calculator\n\n'
                'What can you do?\n'
                '- Eat smaller portions and more vegetables\n'
                '- Choose water instead of sugary drinks\n'
                '- Move your body: walk, swim, or dance\n'
                '- Aim for slow, steady weight loss\n'
                '- Talk to your doctor for help',
      },
      {
        'title': 'Eat Healthy to Lose Weight',
        'category': 'Obesity',
        'imageUrl':
            'https://images.unsplash.com/photo-1661257711676-79a0fc533569',
        'medicalConditionTags': ['Obesity', 'Lose weight', 'Lower cholesterol'],
        'content':
            'What you eat matters when you want to lose weight. Healthy choices can help you feel full and have more energy.\n\n'
                'Try these tips:\n'
                '- Fill half your plate with vegetables\n'
                '- Pick lean proteins like chicken, fish, or beans\n'
                '- Choose whole grains over white bread and rice\n'
                '- Limit sweets, fast food, and fried foods\n'
                '- Drink water or tea instead of soda',
      },
      {
        'title': 'Know Your BMI Number',
        'category': 'Obesity',
        'imageUrl':
            'https://images.unsplash.com/photo-1646829873498-e874cfa27933',
        'medicalConditionTags': ['Obesity', 'Lose weight'],
        'content':
            'Body Mass Index (BMI) is a simple way to check if you have a healthy weight.\n\n'
                'BMI categories:\n'
                '- 18.5–24.9 is healthy weight\n'
                '- 25–29.9 is overweight\n'
                '- 30 or above is obesity\n\n'
                'How to get your BMI:\n'
                '- Use a free online BMI calculator\n'
                '- Enter your height and weight\n'
                '- Talk to your doctor about your number',
      },
      {
        'title': 'Move More to Lose Weight',
        'category': 'Obesity',
        'imageUrl':
            'https://images.unsplash.com/photo-1588528402605-1f9d0eb7a6d6',
        'medicalConditionTags': ['Obesity', 'Lose weight'],
        'content':
            'Moving more helps burn calories and keep a healthy weight.\n\n'
                'Try these:\n'
                '- Walk, dance, or swim for 30 minutes daily\n'
                '- Park farther from stores\n'
                '- Take the stairs instead of elevators\n\n'
                'Start small:\n'
                '- Add five more minutes each week\n'
                '- Find activities you enjoy',
      },

      // Pre-diabetes (4)
      {
        'title': 'What Is Prediabetes?',
        'category': 'Pre-diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1599814516324-66aa0bf16425',
        'medicalConditionTags': ['Pre-diabetes', 'Avoid diabetes'],
        'content':
            'Prediabetes means your blood sugar is higher than normal but not high enough to be diabetes yet. You can still take action to lower your risk.\n\n'
                'Signs to watch:\n'
                '- You may feel very thirsty\n'
                '- You may urinate more often\n'
                '- You might feel tired or shaky\n'
                '- Often there are no clear signs\n\n'
                'What you can do:\n'
                '- Eat more fruits, vegetables, and whole grains\n'
                '- Move daily: walk, bike, or swim\n'
                '- Lose small amounts of weight if needed\n'
                '- Drink water instead of sugary drinks\n'
                '- Ask your doctor about yearly blood tests',
      },
      {
        'title': 'Eat to Prevent Diabetes',
        'category': 'Pre-diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1586810512929-6b8659fde098',
        'medicalConditionTags': [
          'Pre-diabetes',
          'Avoid diabetes',
          'Lower blood glucose (Sugar)'
        ],
        'content':
            'What you eat can help keep your blood sugar in a healthy range. Small changes add up over time.\n\n'
                'Healthy eating tips:\n'
                '- Include whole grains like oats and brown rice\n'
                '- Choose lean proteins: beans, chicken, fish\n'
                '- Fill half your plate with vegetables\n'
                '- Limit sweets and sugary drinks\n'
                '- Eat regular meals to keep sugar steady',
      },
      {
        'title': 'Check Your Blood Sugar for Prediabetes',
        'category': 'Pre-diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1683727186226-910f31a9da45',
        'medicalConditionTags': ['Pre-diabetes', 'Lower blood glucose (Sugar)'],
        'content':
            'Testing your blood sugar helps catch prediabetes early so you can take action.\n\n'
                'Tests to know:\n'
                '- A1C test: 5.7–6.4%\n'
                '- Fasting sugar: 100–125 mg/dL\n'
                '- Two-hour tolerance: 140–199 mg/dL\n\n'
                'Tip:\n'
                '- Repeat tests each year if you are at risk',
      },
      {
        'title': 'Lose Weight to Stop Diabetes',
        'category': 'Pre-diabetes',
        'imageUrl':
            'https://images.unsplash.com/photo-1522844990619-4951c40f7eda',
        'medicalConditionTags': ['Pre-diabetes', 'Lose weight'],
        'content':
            'Losing even a small amount of weight can lower your chance of developing diabetes.\n\n'
                'How much to lose?\n'
                '- Five to seven percent of your body weight helps\n\n'
                'Tips:\n'
                '- Combine healthy eating with daily movement\n'
                '- Track your weight once a week\n'
                '- Celebrate small successes to stay motivated',
      },

      // Nutrition (4)
      {
        'title': 'Eat a Colorful Plate',
        'category': 'Nutrition',
        'imageUrl': 'https://images.unsplash.com/photo-1554899282-3eaf342145c9',
        'medicalConditionTags': [
          'Nutrition',
          'Lower cholesterol',
          'Lower blood pressure',
          'Lower blood glucose (Sugar)'
        ],
        'content':
            'A colorful plate with fruits and vegetables gives your body the vitamins it needs. Bright colors come from different nutrients.\n\n'
                'Ways to add color:\n'
                '- Red: tomatoes, strawberries, red peppers\n'
                '- Orange/Yellow: carrots, oranges, squash\n'
                '- Green: spinach, broccoli, peas\n'
                '- Blue/Purple: berries, eggplant, cabbage\n'
                '- Try to have at least three colors each meal',
      },
      {
        'title': 'Drink Water Every Day',
        'category': 'Nutrition',
        'imageUrl': 'https://images.unsplash.com/photo-1548780607-46c78f38182d',
        'medicalConditionTags': [
          'Nutrition',
          'Lower blood pressure',
          'Lose weight'
        ],
        'content':
            'Water is the best drink for your body. It keeps you hydrated and helps control weight and blood pressure.\n\n'
                'How to drink more water:\n'
                '- Carry a reusable water bottle\n'
                '- Drink a glass before each meal\n'
                '- Add fruit slices for flavor\n'
                '- Choose water instead of soda or juice\n'
                '- Aim for eight cups (64 oz) a day',
      },
      {
        'title': 'Choose Whole Grains',
        'category': 'Nutrition',
        'imageUrl':
            'https://images.unsplash.com/photo-1744217083335-8b57ec3826ac',
        'medicalConditionTags': [
          'Nutrition',
          'Lower blood glucose (Sugar)',
          'Lose weight'
        ],
        'content':
            'Whole grains have more fiber and keep you full longer. They help control blood sugar and weight.\n\n'
                'How to pick:\n'
                '- Look for "100% whole grain" on labels\n'
                '- Try brown rice, oats, or whole-wheat bread\n'
                '- Swap white pasta for whole-grain pasta\n\n'
                'Tip:\n'
                '- Start by swapping one grain each day',
      },
      {
        'title': 'Add Fruits and Veggies First',
        'category': 'Nutrition',
        'imageUrl':
            'https://images.unsplash.com/photo-1681840524567-732960c82f4c',
        'medicalConditionTags': [
          'Nutrition',
          'Lower blood pressure',
          'Avoid diabetes'
        ],
        'content':
            'Starting meals with fruits or vegetables can help you eat less of other foods.\n\n'
                'Ideas:\n'
                '- Begin with a salad or steamed veggies\n'
                '- Fill half your plate with produce\n'
                '- Use raw, roasted, or steamed options\n\n'
                'Benefit:\n'
                '- More vitamins and fiber in each meal',
      },
    ];

    await mongoDBService.educationalContentCollection.insertMany(articles);
    print('Successfully inserted ${articles.length} articles');
  } catch (e) {
    print('Error inserting test articles: $e');
  } finally {
    await mongoDBService.close();
  }
}

// import '../services/mongodb_service.dart';

// Future<void> insertTestArticles() async {
//   final mongoDBService = MongoDBService();
//   await mongoDBService.initialize();

//   try {
//     // First, delete all existing articles
//     print('Dropping existing articles...');
//     await mongoDBService.educationalContentCollection.drop();
//     print('Existing articles dropped successfully');

//     final articles = [
//       // Hypertension (10)
//       {
//         'title': 'What Is High Blood Pressure?',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1584036561566-baf8f5f1b144?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'High blood pressure is also called hypertension. It means the blood in your body is pushing too hard against your blood vessels.\n\n'
//                 'What are the signs?\n'
//                 '- Most people have no signs. That is why you must check your blood pressure regularly.\n'
//                 '- Some people may feel:\n'
//                 '- Headache\n'
//                 '- Dizziness\n'
//                 '- Chest pain\n'
//                 '- Blurry vision\n\n'
//                 'What can you do to stay healthy?\n'
//                 '- Eat less salt\n'
//                 '- Eat more fruits and vegetables\n'
//                 '- Move your body – walk, dance, or play\n'
//                 '- Lose weight if you are overweight\n'
//                 '- Stop drinking too much alcohol',
//       },
//       {
//         'title': 'Easy Ways to Lower Your Blood Pressure',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1555992336-03a23c22b44d?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'Lowering your blood pressure can help your heart and kidneys stay healthy. Small steps can make a big difference.\n\n'
//                 'Steps to try:\n'
//                 '- Eat more fruits and vegetables each day\n'
//                 '- Choose whole grains instead of white bread\n'
//                 '- Walk 30 minutes most days of the week\n'
//                 '- Limit salty and processed foods\n'
//                 '- Talk to your doctor about medicine if needed',
//       },
//       {
//         'title': 'Why Salt Affects Your Heart',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765607928-8e9a0dc5ac7d?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'Salt can make your body hold extra water. This extra water puts more pressure on your heart and blood vessels.\n\n'
//                 'Why salt matters?\n'
//                 '- It raises your blood pressure\n'
//                 '- It makes your heart work harder\n'
//                 '- Most packaged foods are high in salt\n\n'
//                 'What you can do?\n'
//                 '- Use herbs and spices instead of salt\n'
//                 '- Choose fresh foods over processed\n'
//                 '- Read food labels for lower-salt options',
//       },
//       {
//         'title': 'Move More to Control Blood Pressure',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1599058917210-5f4bdcaae650?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'Moving your body helps your heart pump blood better and lowers pressure.\n\n'
//                 'How much activity?\n'
//                 '- Aim for 30 minutes each day\n'
//                 '- You can walk, dance, or bike\n\n'
//                 'Tips to get started:\n'
//                 '- Break into 10-minute chunks\n'
//                 '- Ask a friend or family to join\n'
//                 '- Choose activities you enjoy',
//       },
//       {
//         'title': 'Manage Stress to Lower Pressure',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1506277881540-9b267089825e?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'Stress can raise your blood pressure. Learning simple ways to relax can help your heart.\n\n'
//                 'How stress hurts?\n'
//                 '- Your body releases a fight-or-flight response\n'
//                 '- Your heart beats faster\n\n'
//                 'Relaxation tips:\n'
//                 '- Take deep breaths for 5 minutes\n'
//                 '- Listen to calming music\n'
//                 '- Spend time outdoors\n'
//                 '- Talk to someone you trust',
//       },
//       {
//         'title': 'Check Blood Pressure at Home',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608055-536978e72319?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'Checking your blood pressure at home helps you and your doctor see how you are doing.\n\n'
//                 'How to check:\n'
//                 '- Sit quietly for 5 minutes\n'
//                 '- Keep your arm at heart level\n'
//                 '- Take two readings, one minute apart\n\n'
//                 'Keep a record:\n'
//                 '- Note date, time, and numbers\n'
//                 '- Share results with your doctor',
//       },
//       {
//         'title': 'Heart Healthy DASH Diet',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1512621776951-a57141f2eef?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'The DASH diet is a way of eating that helps lower blood pressure and keeps your heart healthy.\n\n'
//                 'What to eat:\n'
//                 '- Fruits and vegetables each day\n'
//                 '- Whole grains like oats and brown rice\n'
//                 '- Low-fat dairy and lean proteins\n\n'
//                 'What to limit:\n'
//                 '- Foods high in salt\n'
//                 '- Red meat and sweets\n'
//                 '- Sugary drinks',
//       },
//       {
//         'title': 'Take Your Medicine Right',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1582719478188-7f61f08c5072?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'If your doctor prescribes medicine for blood pressure, taking it correctly is very important.\n\n'
//                 'Medicine tips:\n'
//                 '- Take at the same time each day\n'
//                 '- Use a pill box or set reminders\n'
//                 '- Never skip doses without talking to your doctor\n\n'
//                 'Keep track:\n'
//                 '- Note any side effects\n'
//                 '- Tell your doctor at your next visit',
//       },
//       {
//         'title': 'Limit Alcohol Use',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1597457313434-1faafd12b6d0?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'Drinking too much alcohol can raise your blood pressure and harm your heart.\n\n'
//                 'What is too much?\n'
//                 '- More than one drink per day for women\n'
//                 '- More than two drinks per day for men\n\n'
//                 'How to cut back:\n'
//                 '- Switch to water or soda water\n'
//                 '- Have alcohol-free days\n'
//                 '- Set a drink limit each occasion',
//       },
//       {
//         'title': 'Healthy Fats for a Healthy Heart',
//         'category': 'Hypertension',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1550317138-10000687a72b?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Hypertension', 'Lower blood pressure'],
//         'content':
//             'Not all fats are bad. Some fats help your heart stay strong.\n\n'
//                 'Good fats include:\n'
//                 '- Olive oil and canola oil\n'
//                 '- Nuts like almonds and walnuts\n'
//                 '- Fatty fish like salmon and tuna\n\n'
//                 'Fats to avoid:\n'
//                 '- Trans fats in fried foods\n'
//                 '- Foods high in saturated fat like butter',
//       },

//       // Diabetes (10)
//       {
//         'title': 'What Is Diabetes?',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1584395630827-860eee694d7b?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Diabetes',
//           'Lower blood glucose (Sugar)',
//           'Avoid diabetes'
//         ],
//         'content':
//             'Diabetes means the sugar in your blood is too high. Over time, high sugar can hurt your eyes, heart, and kidneys.\n\n'
//                 'How do you know?\n'
//                 '- You may feel very thirsty\n'
//                 '- You might urinate more often\n'
//                 '- You may feel tired or have blurry vision\n'
//                 '- Some people have no clear signs\n\n'
//                 'What can you do?\n'
//                 '- Check your blood sugar as your doctor tells you\n'
//                 '- Eat regular meals with protein and vegetables\n'
//                 '- Move your body for at least 30 minutes most days\n'
//                 '- Take medicine or insulin if prescribed\n'
//                 '- See your doctor for regular check-ups',
//       },
//       {
//         'title': 'Know Your Blood Sugar Numbers',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1581579186373-e8d5f2005612?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Knowing your blood sugar numbers helps you stay in control. Your doctor will tell you your target ranges.\n\n'
//                 'Targets to remember:\n'
//                 '- Before meals: 80–130 mg/dL\n'
//                 '- One to two hours after meals: below 180 mg/dL\n\n'
//                 'Tips:\n'
//                 '- Keep a log of your readings\n'
//                 '- Share your numbers with your care team\n'
//                 '- Ask what your personal goals are',
//       },
//       {
//         'title': 'Healthy Snacks for Diabetes',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1584351055531-9b115f6fbae7?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Choosing the right snacks can keep your blood sugar steady and prevent big rises.\n\n'
//                 'Good snack ideas:\n'
//                 '- A small apple with peanut butter\n'
//                 '- Greek yogurt with berries\n'
//                 '- Veggie sticks with hummus\n'
//                 '- A handful of nuts\n\n'
//                 'Tip:\n'
//                 '- Check your blood sugar after snacks to see how you respond',
//       },
//       {
//         'title': 'Stay Active for Diabetes',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1526401281623-1cbdbf49c00d?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Moving your body helps your cells use sugar and can lower your blood sugar.\n\n'
//                 'Activity tips:\n'
//                 '- Aim for 30 minutes most days\n'
//                 '- Try walking, swimming, or biking\n'
//                 '- Use the stairs instead of elevators\n\n'
//                 'Safety:\n'
//                 '- Check your blood sugar before and after exercise\n'
//                 '- Wear good shoes to protect your feet',
//       },
//       {
//         'title': 'Foot Care for People with Diabetes',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608057-a8a7d0dafdbd?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Diabetes can affect your feet. Taking care of your feet helps prevent problems.\n\n'
//                 'Daily foot care:\n'
//                 '- Wash and dry your feet well\n'
//                 '- Check for cuts or blisters\n'
//                 '- Keep skin soft with lotion (not between toes)\n\n'
//                 'Shoes and nails:\n'
//                 '- Wear well-fitting, comfortable shoes\n'
//                 '- Trim nails straight across\n'
//                 '- Tell your doctor if you see sores',
//       },
//       {
//         'title': 'Prevent Diabetes Complications',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1582719472268-b5c647fbf25d?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Avoid diabetes'],
//         'content':
//             'Keeping your blood sugar in range helps prevent many diabetes complications.\n\n'
//                 'Things to watch:\n'
//                 '- Heart health: control blood pressure\n'
//                 '- Kidney health: check urine protein\n'
//                 '- Eye health: get an eye exam each year\n\n'
//                 'Tips:\n'
//                 '- Take medicines as prescribed\n'
//                 '- Eat healthy and stay active\n'
//                 '- See your doctor regularly',
//       },
//       {
//         'title': 'Medicine Tips for Diabetes',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1582719473492-6ee9f53a536b?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Taking your diabetes medicine correctly helps control blood sugar and keeps you healthy.\n\n'
//                 'Dos and do nots:\n'
//                 '- Take medicines at the same time each day\n'
//                 '- Keep medicines in a cool, dry place\n'
//                 '- Use reminders so you do not miss doses\n\n'
//                 'Talk to your doctor:\n'
//                 '- Report any side effects\n'
//                 '- Ask before stopping any medicine',
//       },
//       {
//         'title': 'Carbohydrate Counting Made Easy',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608223-8fc9f629d5de?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Carbs have the biggest effect on blood sugar. Counting them helps you plan meals.\n\n'
//                 'How to count:\n'
//                 '- Look at the serving size on labels\n'
//                 '- Note grams of carbohydrates\n'
//                 '- Aim for consistent carbs at each meal\n\n'
//                 'Tools:\n'
//                 '- Use carb-counting apps or food lists\n'
//                 '- Ask a dietitian for help',
//       },
//       {
//         'title': 'Understanding A1C Test',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1580281658625-31e3ab30b39e?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'The A1C test shows your average blood sugar over two to three months. It helps your doctor see long-term control.\n\n'
//                 'What A1C means:\n'
//                 '- Below 5.7% is normal\n'
//                 '- 5.7–6.4% means prediabetes\n'
//                 '- 6.5% or above means diabetes\n\n'
//                 'Prepare for the test:\n'
//                 '- Follow your usual routine\n'
//                 '- No fasting is needed\n'
//                 '- Ask your doctor how often to test',
//       },
//       {
//         'title': 'Stress Management for Diabetes',
//         'category': 'Diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1526401281698-56f2b6468c84?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Diabetes', 'Avoid diabetes'],
//         'content':
//             'Stress can raise your blood sugar. Learning ways to relax helps you stay in control.\n\n'
//                 'How stress hurts?\n'
//                 '- Your body releases stress hormones\n'
//                 '- These hormones raise blood sugar\n\n'
//                 'Relaxation steps:\n'
//                 '- Practice deep breathing for five minutes\n'
//                 '- Take short walks in nature\n'
//                 '- Talk with friends or a counselor\n'
//                 '- Do hobbies you enjoy',
//       },

//       // Obesity (10)
//       {
//         'title': 'What Is Obesity?',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608062-199cdb7bb8c0?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight'],
//         'content':
//             'Obesity means having too much body fat. It can raise your risk for heart disease, diabetes, and high blood pressure.\n\n'
//                 'How do you know?\n'
//                 '- Body Mass Index (BMI) over 30 means obesity\n'
//                 '- BMI = weight in kilograms divided by height in meters squared\n'
//                 '- You can use a free online BMI calculator\n\n'
//                 'What can you do?\n'
//                 '- Eat smaller portions and more vegetables\n'
//                 '- Choose water instead of sugary drinks\n'
//                 '- Move your body: walk, swim, or dance\n'
//                 '- Aim for slow, steady weight loss\n'
//                 '- Talk to your doctor for help',
//       },
//       {
//         'title': 'Eat Healthy to Lose Weight',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608069-01aebe047d8d?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight', 'Lower cholesterol'],
//         'content':
//             'What you eat matters when you want to lose weight. Healthy choices can help you feel full and have more energy.\n\n'
//                 'Try these tips:\n'
//                 '- Fill half your plate with vegetables\n'
//                 '- Pick lean proteins like chicken, fish, or beans\n'
//                 '- Choose whole grains over white bread and rice\n'
//                 '- Limit sweets, fast food, and fried foods\n'
//                 '- Drink water or tea instead of soda',
//       },
//       {
//         'title': 'Know Your BMI Number',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608071-f8d1d88fb2ad?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight'],
//         'content':
//             'Body Mass Index (BMI) is a simple way to check if you have a healthy weight.\n\n'
//                 'BMI categories:\n'
//                 '- 18.5–24.9 is a healthy weight\n'
//                 '- 25–29.9 is overweight\n'
//                 '- 30 or above is obesity\n\n'
//                 'How to get your BMI:\n'
//                 '- Use a free online BMI calculator\n'
//                 '- Enter your height and weight\n'
//                 '- Talk to your doctor about your number',
//       },
//       {
//         'title': 'Move More to Lose Weight',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608077-2f98b5315a5c?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight'],
//         'content':
//             'Moving more helps burn calories and keep a healthy weight.\n\n'
//                 'Try these:\n'
//                 '- Walk, dance, or swim for 30 minutes daily\n'
//                 '- Park farther from stores\n'
//                 '- Take the stairs instead of elevators\n\n'
//                 'Start small:\n'
//                 '- Add five more minutes each week\n'
//                 '- Find activities you enjoy',
//       },
//       {
//         'title': 'Limit Sugary Drinks',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608089-3fbbb1d4fc5f?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lower blood glucose (Sugar)'],
//         'content': 'Sugary drinks add extra calories and raise blood sugar.\n\n'
//             'How to cut down:\n'
//             '- Choose water, unsweet tea, or seltzer\n'
//             '- Add fruit slices to water for flavor\n'
//             '- Drink a glass of water before meals\n\n'
//             'Benefits:\n'
//             '- Fewer empty calories\n'
//             '- Better weight control',
//       },
//       {
//         'title': 'Small Steps to a Healthy Weight',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608097-68b9b925fade?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight'],
//         'content':
//             'Small changes add up over time and make healthy habits easier.\n\n'
//                 'Ideas to try:\n'
//                 '- Walk an extra five minutes each day\n'
//                 '- Swap one snack for fruit\n'
//                 '- Take stairs instead of elevator\n'
//                 '- Park farther from entrances\n\n'
//                 'Remember:\n'
//                 '- Every step counts toward your goal',
//       },
//       {
//         'title': 'Sleep Well for Weight Control',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608101-7fb0a3fc8c70?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight'],
//         'content':
//             'Good sleep helps control your hunger hormones and keeps weight steady.\n\n'
//                 'Sleep tips:\n'
//                 '- Aim for seven to nine hours each night\n'
//                 '- Keep a regular bedtime and wake time\n'
//                 '- Avoid screens one hour before bed\n\n'
//                 'Benefits:\n'
//                 '- Better appetite control\n'
//                 '- More energy for activity',
//       },
//       {
//         'title': 'Drink Water for Weight Loss',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608105-835951c0a67f?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight'],
//         'content': 'Water has zero calories and can help you feel full.\n\n'
//             'How to drink more:\n'
//             '- Drink a glass of water before meals\n'
//             '- Carry a bottle and sip throughout the day\n'
//             '- Sometimes thirst feels like hunger\n\n'
//             'Benefits:\n'
//             '- Fewer calories consumed\n'
//             '- Better energy levels',
//       },
//       {
//         'title': 'Healthy Cooking for Weight Control',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight', 'Lower cholesterol'],
//         'content':
//             'Cooking at home helps you control ingredients and calories.\n\n'
//                 'Healthy cooking tips:\n'
//                 '- Use healthy oils like olive oil\n'
//                 '- Steam or bake instead of frying\n'
//                 '- Add herbs and spices for flavor\n\n'
//                 'Plan ahead:\n'
//                 '- Batch-cook meals and freeze portions\n'
//                 '- Use smaller pans for portion control',
//       },
//       {
//         'title': 'Importance of Breakfast',
//         'category': 'Obesity',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1490818387583-1baba5e638af?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Obesity', 'Lose weight'],
//         'content':
//             'Eating breakfast starts your metabolism and gives energy for the day.\n\n'
//                 'Good breakfast ideas:\n'
//                 '- Oatmeal with fruit\n'
//                 '- Whole-grain toast with peanut butter\n'
//                 '- Yogurt with berries and nuts\n\n'
//                 'Tip:\n'
//                 '- Aim to eat within one hour of waking up\n'
//                 '- A healthy breakfast can reduce overeating later',
//       },

//       // Pre-diabetes (10)
//       {
//         'title': 'What Is Prediabetes?',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608117-9b44da1d7c5a?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Avoid diabetes'],
//         'content':
//             'Prediabetes means your blood sugar is higher than normal but not high enough to be diabetes yet. You can still take action to lower your risk.\n\n'
//                 'Signs to watch:\n'
//                 '- You may feel very thirsty\n'
//                 '- You may urinate more often\n'
//                 '- You might feel tired or shaky\n'
//                 '- Often there are no clear signs\n\n'
//                 'What you can do:\n'
//                 '- Eat more fruits, vegetables, and whole grains\n'
//                 '- Move daily: walk, bike, or swim\n'
//                 '- Lose small amounts of weight if needed\n'
//                 '- Drink water instead of sugary drinks\n'
//                 '- Ask your doctor about yearly blood tests',
//       },
//       {
//         'title': 'Eat to Prevent Diabetes',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608139-52770ed25d1d?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Pre-diabetes',
//           'Avoid diabetes',
//           'Lower blood glucose (Sugar)'
//         ],
//         'content':
//             'What you eat can help keep your blood sugar in a healthy range. Small changes add up over time.\n\n'
//                 'Healthy eating tips:\n'
//                 '- Include whole grains like oats and brown rice\n'
//                 '- Choose lean proteins: beans, chicken, fish\n'
//                 '- Fill half your plate with vegetables\n'
//                 '- Limit sweets and sugary drinks\n'
//                 '- Eat regular meals to keep sugar steady',
//       },
//       {
//         'title': 'Check Your Blood Sugar for Prediabetes',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608123-0d02de7df510?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Testing your blood sugar helps catch prediabetes early so you can take action.\n\n'
//                 'Tests to know:\n'
//                 '- A1C test: 5.7–6.4%\n'
//                 '- Fasting sugar: 100–125 mg/dL\n'
//                 '- Two-hour tolerance: 140–199 mg/dL\n\n'
//                 'Tip:\n'
//                 '- Repeat tests each year if you are at risk',
//       },
//       {
//         'title': 'Lose Weight to Stop Diabetes',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608151-0f4d4b275dbf?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Lose weight'],
//         'content':
//             'Losing even a small amount of weight can lower your chance of developing diabetes.\n\n'
//                 'How much to lose?\n'
//                 '- Five to seven percent of your body weight helps\n\n'
//                 'Tips:\n'
//                 '- Combine healthy eating with daily movement\n'
//                 '- Track your weight once a week\n'
//                 '- Celebrate small successes to stay motivated',
//       },
//       {
//         'title': 'Move to Reverse Prediabetes',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608145-d6bfaee9ac8c?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Physical activity helps your body use sugar better and can reverse prediabetes.\n\n'
//                 'Activity goals:\n'
//                 '- Aim for 150 minutes of brisk walking weekly\n'
//                 '- Include strength training twice a week\n\n'
//                 'Safety tips:\n'
//                 '- Warm up and cool down\n'
//                 '- Check your blood sugar before and after exercise',
//       },
//       {
//         'title': 'Skip Sugary Drinks',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608160-510429b6492a?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Sugary drinks can spike your blood sugar and add empty calories.\n\n'
//                 'What to choose:\n'
//                 '- Water, unsweet tea, or seltzer\n'
//                 '- Add lemon or mint to flavor water\n\n'
//                 'Tip:\n'
//                 '- Drink water before meals to help control hunger',
//       },
//       {
//         'title': 'See Your Doctor for Prediabetes Tests',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608166-5f9dcdf1e7a7?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Avoid diabetes'],
//         'content':
//             'Regular tests help find prediabetes early so you can take action.\n\n'
//                 'What to ask for:\n'
//                 '- A1C test\n'
//                 '- Fasting blood sugar\n'
//                 '- Two-hour glucose tolerance test\n\n'
//                 'Next steps:\n'
//                 '- Repeat tests yearly if at risk\n'
//                 '- Join a diabetes prevention program if available',
//       },
//       {
//         'title': 'Healthy Eating for Prediabetes',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1589715289241-b9af94f55f40?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Pre-diabetes',
//           'Avoid diabetes',
//           'Lower blood glucose (Sugar)'
//         ],
//         'content':
//             'Eating healthy foods can help lower your blood sugar and avoid diabetes.\n\n'
//                 'Foods to include:\n'
//                 '- Plenty of vegetables and fruits\n'
//                 '- Lean proteins like fish and beans\n'
//                 '- Whole grains over refined grains\n\n'
//                 'Foods to limit:\n'
//                 '- Sweets and pastries\n'
//                 '- Sugary drinks\n'
//                 '- High-fat meats',
//       },
//       {
//         'title': 'Strength Training to Lower Blood Sugar',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608171-936dc1e3814e?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Lower blood glucose (Sugar)'],
//         'content':
//             'Strength training builds muscle that uses sugar for energy, helping lower blood sugar.\n\n'
//                 'Exercises to try:\n'
//                 '- Light weight lifting twice a week\n'
//                 '- Bodyweight moves: squats, push-ups\n\n'
//                 'Tips:\n'
//                 '- Learn proper form to avoid injury\n'
//                 '- Start light and increase slowly\n'
//                 '- Ask a trainer if you need help',
//       },
//       {
//         'title': 'Stress Reduction to Prevent Diabetes',
//         'category': 'Pre-diabetes',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608178-21dd3e42a1b4?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Pre-diabetes', 'Avoid diabetes'],
//         'content':
//             'Reducing stress helps keep your blood sugar steady and lowers diabetes risk.\n\n'
//                 'How stress affects you:\n'
//                 '- Raises blood sugar levels\n'
//                 '- Leads to unhealthy food choices\n\n'
//                 'Ways to reduce stress:\n'
//                 '- Practice yoga or tai chi\n'
//                 '- Meditate for a few minutes daily\n'
//                 '- Spend time with loved ones\n'
//                 '- Take breaks and do deep breathing',
//       },

//       // Nutrition (10)
//       {
//         'title': 'Eat a Colorful Plate',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1556912167-f556f1f39aec?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lower cholesterol',
//           'Lower blood pressure',
//           'Lower blood glucose (Sugar)'
//         ],
//         'content':
//             'A colorful plate with fruits and vegetables gives your body the vitamins it needs. Bright colors come from different nutrients.\n\n'
//                 'Ways to add color:\n'
//                 '- Red: tomatoes, strawberries, red peppers\n'
//                 '- Orange/Yellow: carrots, oranges, squash\n'
//                 '- Green: spinach, broccoli, peas\n'
//                 '- Blue/Purple: berries, eggplant, cabbage\n'
//                 '- Try to have at least three colors each meal',
//       },
//       {
//         'title': 'Drink Water Every Day',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1593032465174-3f4d0d1f79bf?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lower blood pressure',
//           'Lose weight'
//         ],
//         'content':
//             'Water is the best drink for your body. It keeps you hydrated and helps control weight and blood pressure.\n\n'
//                 'How to drink more water:\n'
//                 '- Carry a reusable water bottle\n'
//                 '- Drink a glass before each meal\n'
//                 '- Add fruit slices for flavor\n'
//                 '- Choose water instead of soda or juice\n'
//                 '- Aim for eight cups (64 oz) a day',
//       },
//       {
//         'title': 'Choose Whole Grains',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1605462863863-76a51a73a53f?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lower blood glucose (Sugar)',
//           'Lose weight'
//         ],
//         'content':
//             'Whole grains have more fiber and keep you full longer. They help control blood sugar and weight.\n\n'
//                 'How to pick:\n'
//                 '- Look for "100% whole grain" on labels\n'
//                 '- Try brown rice, oats, or whole-wheat bread\n'
//                 '- Swap white pasta for whole-grain pasta\n\n'
//                 'Tip:\n'
//                 '- Start by swapping one grain each day',
//       },
//       {
//         'title': 'Add Fruits and Veggies First',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608186-a997bf43e6fc?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lower blood pressure',
//           'Avoid diabetes'
//         ],
//         'content':
//             'Starting meals with fruits or vegetables can help you eat less of other foods.\n\n'
//                 'Ideas:\n'
//                 '- Begin with a salad or steamed veggies\n'
//                 '- Fill half your plate with produce\n'
//                 '- Use raw, roasted, or steamed options\n\n'
//                 'Benefit:\n'
//                 '- More vitamins and fiber in each meal',
//       },
//       {
//         'title': 'Limit Sugar and Salt',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608192-87dd9f32721c?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lower cholesterol',
//           'Lower blood pressure',
//           'Lower blood glucose (Sugar)'
//         ],
//         'content':
//             'Too much sugar and salt can harm your health. Cutting back helps control weight, pressure, and blood sugar.\n\n'
//                 'What to watch:\n'
//                 '- Compare labels for lower sugar and salt\n'
//                 '- Use herbs and spices instead of salt\n'
//                 '- Skip sugary drinks and sweets\n\n'
//                 'Small steps:\n'
//                 '- Cut one teaspoon of sugar per day\n'
//                 '- Choose low-salt options when shopping',
//       },
//       {
//         'title': 'Balance Your Plate with Protein',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608199-2d7fefd7b104?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Nutrition', 'Lose weight', 'Avoid diabetes'],
//         'content':
//             'Protein helps keep you full and supports muscles. Pair it with vegetables and grains for a balanced meal.\n\n'
//                 'Good protein sources:\n'
//                 '- Beans, lentils, and peas\n'
//                 '- Fish, chicken, and lean meats\n'
//                 '- Eggs, yogurt, and cheese\n\n'
//                 'Tip:\n'
//                 '- Include a source of protein at each meal',
//       },
//       {
//         'title': 'Healthy Snacks to Feel Full',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1597304603616-1bc32868c145?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lose weight',
//           'Lower blood glucose (Sugar)'
//         ],
//         'content':
//             'Healthy snacks between meals can keep energy steady and prevent overeating.\n\n'
//                 'Snack ideas:\n'
//                 '- Apple slices with peanut butter\n'
//                 '- Greek yogurt with berries\n'
//                 '- Veggies with hummus\n'
//                 '- A handful of nuts\n\n'
//                 'Tip:\n'
//                 '- Keep snacks to one healthy serving size',
//       },
//       {
//         'title': 'Cook at Home for Better Health',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608204-bbb3a589fbbc?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lower cholesterol',
//           'Lower blood pressure'
//         ],
//         'content':
//             'Cooking at home lets you control ingredients and portions, which can improve health and save money.\n\n'
//                 'Easy tips:\n'
//                 '- Use less oil, salt, and sugar\n'
//                 '- Try simple soups, stir-fries, or salads\n'
//                 '- Batch-cook meals and freeze portions\n\n'
//                 'Benefit:\n'
//                 '- You know what goes into your food',
//       },
//       {
//         'title': 'Read the Food Label',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608210-207ae82a451c?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': [
//           'Nutrition',
//           'Lower blood glucose (Sugar)',
//           'Lower blood pressure'
//         ],
//         'content':
//             'Food labels help you pick healthier options by showing key nutrition facts.\n\n'
//                 'What to check:\n'
//                 '- Serving size first\n'
//                 '- Grams of sugar and sodium\n'
//                 '- Calories and fiber\n\n'
//                 'Tip:\n'
//                 '- Compare similar products and choose lower numbers',
//       },
//       {
//         'title': 'Small Steps to Eat Healthier',
//         'category': 'Nutrition',
//         'imageUrl':
//             'https://images.unsplash.com/photo-1576765608217-aa7f9d0c0d9f?w=800&auto=format&fit=crop&q=60',
//         'medicalConditionTags': ['Nutrition', 'Lose weight', 'Avoid diabetes'],
//         'content':
//             'Making small, consistent changes is easier and more sustainable than big shifts.\n\n'
//                 'Ideas to start:\n'
//                 '- Swap soda for water once a day\n'
//                 '- Add one extra vegetable serving\n'
//                 '- Use smaller plates to eat less\n'
//                 '- Try one new healthy recipe each week\n\n'
//                 'Remember:\n'
//                 '- Each small change is a step toward better health',
//       },
//     ];

//     await mongoDBService.educationalContentCollection.insertMany(articles);
//     print('Successfully inserted ${articles.length} articles');
//   } catch (e) {
//     print('Error inserting test articles: $e');
//   } finally {
//     await mongoDBService.close();
//   }
// }
