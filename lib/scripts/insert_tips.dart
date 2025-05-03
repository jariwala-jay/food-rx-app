import '../models/tip.dart';
import '../services/mongodb_service.dart';

Future<void> insertTips() async {
  final mongoDBService = MongoDBService();
  await mongoDBService.initialize();

  final collection = mongoDBService.db.collection('tips');

  // Clear existing tips
  await collection.remove({});

  // Hypertension Tips
  final hypertensionTips = [
    Tip(
      id: 'ht1',
      title: 'Reduce Sodium Intake',
      description:
          'Limit your daily sodium intake to less than 2,300 mg. Read food labels and choose low-sodium options.',
      category: 'Hypertension',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    ),
    Tip(
      id: 'ht2',
      title: 'Regular Exercise',
      description:
          'Aim for at least 30 minutes of moderate exercise most days of the week to help lower blood pressure.',
      category: 'Hypertension',
      imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b',
    ),
    Tip(
      id: 'ht3',
      title: 'Manage Stress',
      description:
          'Practice relaxation techniques like deep breathing, meditation, or yoga to help control blood pressure.',
      category: 'Hypertension',
      imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
    ),
    Tip(
      id: 'ht4',
      title: 'Limit Alcohol',
      description:
          'Keep alcohol consumption moderate - no more than one drink per day for women and two for men.',
      category: 'Hypertension',
      imageUrl: 'https://images.unsplash.com/photo-1514362545857-3bc4c454ad83',
    ),
    Tip(
      id: 'ht5',
      title: 'Eat Potassium-Rich Foods',
      description:
          'Include bananas, sweet potatoes, spinach, and avocados in your diet to help lower blood pressure.',
      category: 'Hypertension',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    ),
  ];

  // Diabetes Tips
  final diabetesTips = [
    Tip(
      id: 'dm1',
      title: 'Monitor Blood Sugar',
      description:
          'Check your blood sugar levels regularly and keep a log to track patterns and make necessary adjustments.',
      category: 'Diabetes',
      imageUrl: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef',
    ),
    Tip(
      id: 'dm2',
      title: 'Balanced Meals',
      description:
          'Focus on balanced meals with proper portions of carbohydrates, proteins, and healthy fats.',
      category: 'Diabetes',
      imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061',
    ),
    Tip(
      id: 'dm3',
      title: 'Stay Active',
      description:
          'Regular physical activity helps control blood sugar levels and improves insulin sensitivity.',
      category: 'Diabetes',
      imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b',
    ),
    Tip(
      id: 'dm4',
      title: 'Fiber-Rich Foods',
      description:
          'Include plenty of fiber in your diet from vegetables, fruits, and whole grains to help control blood sugar.',
      category: 'Diabetes',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    ),
    Tip(
      id: 'dm5',
      title: 'Regular Check-ups',
      description:
          'Schedule regular appointments with your healthcare provider to monitor your condition and adjust treatment.',
      category: 'Diabetes',
      imageUrl: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef',
    ),
  ];

  // Prediabetes Tips
  final prediabetesTips = [
    Tip(
      id: 'pd1',
      title: 'Lose Weight',
      description:
          'Losing even a small amount of weight can help prevent or delay the onset of type 2 diabetes.',
      category: 'Prediabetes',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    ),
    Tip(
      id: 'pd2',
      title: 'Choose Whole Grains',
      description:
          'Opt for whole grains over refined grains to help control blood sugar levels.',
      category: 'Prediabetes',
      imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061',
    ),
    Tip(
      id: 'pd3',
      title: 'Regular Check-ups',
      description:
          'Schedule regular check-ups with your healthcare provider to monitor your condition.',
      category: 'Prediabetes',
      imageUrl: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef',
    ),
    Tip(
      id: 'pd4',
      title: 'Stay Hydrated',
      description:
          'Drink plenty of water and limit sugary beverages to help maintain healthy blood sugar levels.',
      category: 'Prediabetes',
      imageUrl: 'https://images.unsplash.com/photo-1551269901-5c5e14c25df7',
    ),
    Tip(
      id: 'pd5',
      title: 'Manage Stress',
      description:
          'Practice stress management techniques as chronic stress can affect blood sugar levels.',
      category: 'Prediabetes',
      imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
    ),
  ];

  // Obesity Tips
  final obesityTips = [
    Tip(
      id: 'ob1',
      title: 'Portion Control',
      description:
          'Use smaller plates and be mindful of portion sizes to help control calorie intake.',
      category: 'Obesity',
      imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061',
    ),
    Tip(
      id: 'ob2',
      title: 'Stay Hydrated',
      description:
          'Drink plenty of water throughout the day and limit sugary beverages.',
      category: 'Obesity',
      imageUrl: 'https://images.unsplash.com/photo-1551269901-5c5e14c25df7',
    ),
    Tip(
      id: 'ob3',
      title: 'Regular Exercise',
      description:
          'Start with small, achievable goals and gradually increase your activity level.',
      category: 'Obesity',
      imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b',
    ),
    Tip(
      id: 'ob4',
      title: 'Mindful Eating',
      description:
          'Pay attention to hunger cues and eat slowly to prevent overeating.',
      category: 'Obesity',
      imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061',
    ),
    Tip(
      id: 'ob5',
      title: 'Sleep Well',
      description:
          'Aim for 7-9 hours of quality sleep as poor sleep can contribute to weight gain.',
      category: 'Obesity',
      imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
    ),
  ];

  // General Health Tips
  final generalTips = [
    Tip(
      id: 'gh1',
      title: 'Sleep Well',
      description:
          'Aim for 7-9 hours of quality sleep each night to support overall health.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
    ),
    Tip(
      id: 'gh2',
      title: 'Eat More Vegetables',
      description:
          'Include a variety of colorful vegetables in your meals for essential nutrients.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    ),
    Tip(
      id: 'gh3',
      title: 'Stay Active',
      description:
          'Find activities you enjoy and make them a regular part of your routine.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b',
    ),
    Tip(
      id: 'gh4',
      title: 'Stay Hydrated',
      description:
          'Drink plenty of water throughout the day to maintain proper hydration.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1551269901-5c5e14c25df7',
    ),
    Tip(
      id: 'gh5',
      title: 'Practice Mindfulness',
      description:
          'Take time each day to practice mindfulness and reduce stress.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
    ),
    Tip(
      id: 'gh6',
      title: 'Eat Whole Foods',
      description:
          'Choose whole, unprocessed foods over processed options for better nutrition.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061',
    ),
    Tip(
      id: 'gh7',
      title: 'Limit Added Sugar',
      description:
          'Reduce your intake of added sugars to maintain better overall health.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1514362545857-3bc4c454ad83',
    ),
    Tip(
      id: 'gh8',
      title: 'Regular Check-ups',
      description:
          'Schedule regular health check-ups to monitor your overall well-being.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef',
    ),
    Tip(
      id: 'gh9',
      title: 'Practice Gratitude',
      description:
          'Take time each day to reflect on things you are grateful for.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b',
    ),
    Tip(
      id: 'gh10',
      title: 'Maintain Social Connections',
      description:
          'Stay connected with friends and family for better mental and emotional health.',
      category: 'General',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    ),
  ];

  // Insert all tips
  final allTips = [
    ...hypertensionTips,
    ...diabetesTips,
    ...prediabetesTips,
    ...obesityTips,
    ...generalTips,
  ];

  for (final tip in allTips) {
    await collection.insert(tip.toJson());
  }

  print('Successfully inserted ${allTips.length} tips into MongoDB');
  await mongoDBService.db.close();
}
