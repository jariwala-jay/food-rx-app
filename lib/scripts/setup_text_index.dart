import '../services/mongodb_service.dart';

Future<void> setupTextIndex() async {
  final mongoDBService = MongoDBService();
  await mongoDBService.initialize();

  try {
    // Create text index on title and content fields
    await mongoDBService.educationalContentCollection.createIndex(
      keys: {
        'title': 'text',
        'content': 'text',
      },
      name: 'article_text_search',
    );
    print('Successfully created text index for article search');
  } catch (e) {
    print('Error creating text index: $e');
  } finally {
    await mongoDBService.close();
  }
}
