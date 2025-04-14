import '../services/mongodb_service.dart';

Future<void> insertTestArticles() async {
  final mongoDBService = MongoDBService();
  await mongoDBService.initialize();

  final articles = [
    {
      'title': 'Understanding Hypertension',
      'category': 'Hypertension',
      'imageUrl':
          'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Hypertension', 'High Blood Pressure'],
      'content': 'Learn about the causes and management of hypertension...',
    },
    {
      'title': 'Diabetes Management Guide',
      'category': 'Diabetes',
      'imageUrl':
          'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Diabetes', 'Type 2 Diabetes'],
      'content': 'Essential tips for managing diabetes effectively...',
    },
    {
      'title': 'Healthy Eating for Weight Loss',
      'category': 'Nutrition',
      'imageUrl':
          'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Obesity', 'Weight Management'],
      'content': 'Discover the best foods for healthy weight loss...',
    },
    {
      'title': 'Exercise for Heart Health',
      'category': 'Heart Disease',
      'imageUrl':
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Heart Disease', 'Cardiovascular Health'],
      'content': 'Safe and effective exercises for heart health...',
    },
    {
      'title': 'DASH Diet Basics',
      'category': 'Nutrition',
      'imageUrl':
          'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Hypertension', 'Heart Disease'],
      'content': 'Introduction to the DASH diet and its benefits...',
    },
    {
      'title': 'Managing Blood Sugar Levels',
      'category': 'Diabetes',
      'imageUrl':
          'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Diabetes', 'Blood Sugar Control'],
      'content': 'Tips for maintaining healthy blood sugar levels...',
    },
    {
      'title': 'Portion Control Guide',
      'category': 'Nutrition',
      'imageUrl':
          'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Obesity', 'Weight Management'],
      'content': 'Learn how to control portion sizes effectively...',
    },
    {
      'title': 'Stress Management Techniques',
      'category': 'Hypertension',
      'imageUrl':
          'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&auto=format&fit=crop&q=60',
      'medicalConditionTags': ['Hypertension', 'Stress Management'],
      'content': 'Effective ways to manage stress for better health...',
    },
  ];

  try {
    await mongoDBService.educationalContentCollection.insertMany(articles);
    print('Successfully inserted ${articles.length} test articles');
  } catch (e) {
    print('Error inserting test articles: $e');
  } finally {
    await mongoDBService.close();
  }
}
